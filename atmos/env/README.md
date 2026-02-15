# Environments

An environment bridges external events (timers, key presses, network packets,
GUI interactions, etc.) into an Atmos application.

There are two layers to understand:

```
User code  -->  Lua env  -->  C env
                (bridge)
```

The **C env** provides a raw API.
The **Lua env** bridges it into a uniform interface for the user.

## C Environment API

The C environment provides one of three raw patterns:

| C API pattern  | What it gives you                              | Examples                |
|----------------|------------------------------------------------|-------------------------|
| `poll()`       | Check once, return                             | SDL, luasocket, clock   |
| `main_loop()`  | Block until quit                               | IUP                     |
| *(implicit)*   | Events just arrive, no loop to enter           | JS browser              |

### Poll dimensions

`poll` is not one thing -- it has two sub-dimensions:

**Blocking behavior** (timeout):

| Variant      | Blocks?               | Example                                    |
|--------------|-----------------------|--------------------------------------------|
| `poll(0)`    | No, return immediately | `SDL_PollEvent`                            |
| `poll(t)`    | Up to t ms            | `SDL_WaitEventTimeout`, `socket:receive`   |
| `poll(inf)`  | Until event arrives   | `SDL_WaitEvent`, blocking `socket:receive` |

**Event reporting**:

| Style            | Who dispatches?                        | Example                          |
|------------------|----------------------------------------|----------------------------------|
| Returns event    | Lua env decides what to do with it     | SDL (returns event struct), socket (returns data) |
| Opaque callbacks | C dispatches via pre-registered callbacks | `iup.LoopStep()`              |

The full spectrum from most to least control:

```
poll(0) --> poll(t) --> poll(inf) --> main_loop --> implicit
------------------------------------------------------------->
  you drive everything              it drives everything
```

`main_loop` is just `poll(inf)` repeated inside C with callback dispatch.
`implicit` is a loop you can't even see.

## Lua Environment Bridge

The Lua env's job is to bridge the C API into one of two user-facing patterns:
**`loop`** (blocks) or **`start`** (returns immediately).

| Environment        | C env gives   | Lua env does                            | User calls     |
|--------------------|---------------|-----------------------------------------|----------------|
| SDL / Clock / Pico | `poll()`      | wraps in `while do poll(); tick() end`  | `loop(body)`   |
| Socket             | `poll()`      | wraps in `while do poll(); tick() end`  | `loop(body)`   |
| IUP                | `poll()` (*)  | wraps in `while do poll(); tick() end`  | `loop(body)`   |
| JS / Web           | *(implicit)*  | registers callbacks, returns            | `start(body)`  |

(*) IUP can use `iup.LoopStepWait()` which is `poll(inf)` --
see "Why IUP uses step" below.

The key insight: the Lua layer can **upgrade** poll into loop (by adding a
while loop), but it cannot change blocking into non-blocking. JS has no loop
to enter -- events just happen -- so it can only be `start`.

### Why IUP uses step (not its own MainLoop)

IUP provides both `iup.MainLoop()` (blocks until quit) and
`iup.LoopStepWait()` (processes events and returns).
Using `LoopStepWait()` means the Lua bridge wraps it in the same
`while do poll(); tick() end` pattern as SDL and the others.

This simplifies the design: all `loop` environments use the same bridge
code -- just a different `poll` function. IUP's poll dispatches via
callbacks instead of returning events, but the while-loop wrapper is
identical.

## User-Facing API

From the user's perspective, there are only two patterns:

```lua
-- loop: blocking, runs step loop, returns when body finishes
loop(function ()
    ...
end)

-- start: non-blocking, spawns body, returns immediately
start(function ()
    ...
end)
```

## Environment Table

Each environment registers a table with up to three callbacks:

| Callback   | Description                                      |
|------------|--------------------------------------------------|
| `open()`   | Initialize / re-initialize resources             |
| `step()`   | Poll once for external events, emit them         |
| `close()`  | Release resources (called by `stop`)             |

### Lifecycle

`open` and `close` are symmetric: `open` is called when an application
starts (`loop` or `start`), `close` is called during teardown (`stop`).
This allows multiple `loop()` invocations within the same process --
each invocation re-initializes via `open` and tears down via `close`.

Initialization code lives in `open`, not at `require` time.  The module
file sets up the Lua-side structure; `open` initializes the C backend.

```
require       open        step...step      close
  |             |             |               |
  module        C init        event loop      C teardown
  structure     (SDL.init,    (poll/emit)     (SDL.quit,
  (metatables,  pico.init,                    pico.init(false),
   env table)   iup.Open)                     iup.Close)
```

`loop` uses `step` to drive the event loop.  `start` does not --
the environment itself drives events (e.g. JS browser callbacks).

### Teardown: `close` vs `stop`

There are two levels of teardown:

- **`close()`** -- kills all tasks, running their `<close>` handlers
  (defers).  The environment is still alive at this point, so cleanup
  code inside tasks can use environment resources (e.g. save state,
  close windows).

- **`stop()`** -- full teardown: calls `close()` first (kill tasks),
  then `_env_.close()` (release environment resources).

```lua
function run.stop ()
    run.close()          -- 1. kill tasks  (env still alive)
    if _env_.close then
        _env_.close()    -- 2. tear down env
    end
end
```

The ordering matters: tasks before environment, so that task cleanup
can still use the environment.

`loop` calls `stop()` automatically when the step loop exits (via a
deferred `<close>` handler).

`start` does **not** call `stop()` automatically -- the environment
backend must arrange for it at the appropriate time.  For example, a
JS environment would register a `beforeunload` listener:

```lua
-- inside a JS environment implementation
window:addEventListener('beforeunload', function ()
    atmos.stop()
end)
```

### Which environments provide what

| Environment        | `open` | `step` | `close` | User calls  |
|--------------------|--------|--------|---------|-------------|
| Clock              |        | yes    |         | `loop`      |
| SDL                | yes    | yes    | yes     | `loop`      |
| Pico               | yes    | yes    | yes     | `loop`      |
| Socket             |        | yes    |         | `loop`      |
| IUP                | yes    | yes    | yes     | `loop`      |
| JS / Web (planned) |        |        | yes     | `start`     |

### Timeout and efficiency

The timeout in `step` determines whether the Lua while-loop busy-waits or
sleeps:

- `poll(0)` (SDL_PollEvent): needs the Lua loop to add its own sleep to
  avoid busy-waiting
- `poll(t)` or `poll(inf)` (SDL_WaitEvent, socket with timeout): the C
  call itself sleeps, so the while-loop is naturally efficient

### `loop` vs `start`

`loop` vs `start` is not about the C API. It is purely about whether the
Lua bridge can run a while-loop or not. JS can't (no thread to block),
everyone else can.

## Multiple Environments

An application may combine environments -- for example, IUP for the GUI
and socket for network I/O.  When multiple environments are loaded, one
becomes **primary** (drives the loop, generates clock events) and the
others become **secondary** (non-blocking, no clock).

### Registration order

`atmos.env()` tracks calls:

1. **1st call** -- the env is registered normally.  `mode.current` stays
   `nil`.  The env behaves autonomously (single-env mode).
2. **2nd call** -- triggers multi-env mode:
   - The 1st env is retroactively set as **primary** (`mode.current = 'primary'`).
   - The 2nd env is set as **secondary** (`mode.current = 'secondary'`).
   - Capability assertions fire at this point (see below).
3. **3rd+ calls** -- each new env is set as secondary.

```lua
require "atmos.env.iup"       -- 1st: registered, mode.current = nil
require "atmos.env.socket"    -- 2nd: iup -> primary, socket -> secondary
```

### The `mode` table

Each environment that supports multi-env declares a `mode` field on the
table passed to `atmos.env()`:

```lua
mode = {
    primary   = bool,    -- can this env act as primary?
    secondary = bool,    -- can this env act as secondary?
    current   = nil,     -- set by atmos.env(): nil | 'primary' | 'secondary'
}
```

- `mode = nil` -- the env can **only run alone**.  `atmos.env()` asserts
  that no other env is registered (before or after).
- `mode.primary = true` -- the env knows how to be primary (bounded step,
  clock generation).
- `mode.secondary = true` -- the env knows how to be secondary (non-blocking
  step, no clock).
- `mode.current` -- **managed by `atmos.env()`**, never set by the module.
  Initially `nil` (single-env, autonomous).  Set to `'primary'` or
  `'secondary'` only when a 2nd env is registered.

### Assertions

1. **Single-env guard** -- if `mode` is `nil`, `atmos.env()` asserts that
   `_envs_` is empty.  Fires if a `mode = nil` env is registered after
   another, or if another env is registered after a `mode = nil` one.
   Error: `"invalid env : single-env only (mode not set)"` /
   `"invalid env : previous env is single-env only (mode not set)"`.
2. **Primary** -- when the 2nd env is registered, the 1st must have
   `mode.primary == true`.
   Error: `"invalid env : primary mode not supported"`.
3. **Secondary** -- the 2nd+ env must have `mode.secondary == true`.
   Error: `"invalid env : secondary mode not supported"`.

An env with `mode = nil` works fine alone but asserts if combined
with any other env.

### Primary contract

A primary environment:

- **Generates clock events** (`emit('clock', dt, now)`).
- **May block in step**, but with a bounded timeout so that secondary envs
  get time slices.

When `mode.current == nil` (single-env), there are no constraints -- the
env may block indefinitely.  The bounded-blocking constraint only applies
when `mode.current == 'primary'`.

### Secondary contract

A secondary environment:

- **Must not block**: step uses a non-blocking variant (e.g.
  `socket.select` with timeout `0`, `iup.LoopStep()` instead of
  `LoopStepWait()`).
- **Must not generate clock events**: the primary owns the clock.
- **Still emits its own domain events** (socket recv/send, GUI callbacks,
  etc.).

### Internal check

Each env's `step` function checks `mode.current` and adjusts:

```lua
function M.step ()
    local cur = M.mode and M.mode.current
    if cur == 'secondary' then
        -- non-blocking poll, no clock emit
    elseif cur == 'primary' then
        -- bounded blocking poll, emit clock
    else
        -- nil: single env, autonomous (may block, emits clock)
    end
end
```

### Loop with multiple envs

The main loop calls all registered envs in order -- primary first
(may block briefly), then secondaries (non-blocking):

```
while true do
    for each env do
        if env.step() then quit end
    end
end
```

### Capabilities

| env    | primary | secondary | mode  | notes                                                  |
|--------|---------|-----------|-------|--------------------------------------------------------|
| clock  | --      | --        | `nil` | simple testing/pedagogical env; single-env only        |
| socket | yes     | yes       | set   | as secondary: `select` with timeout=0, no clock        |
| sdl    | yes     | yes       | set   | as secondary: `waitEvent(0)`, no clock, still emits draw/input |
| pico   | yes     | yes       | set   | as secondary: `input.event(0)`, no clock, still emits draw/input |
| iup    | yes     | yes       | set   | as secondary: `LoopStep()`, disable timer              |

### `loop` vs `start` in multi-env

Multi-env only works with `loop`-based environments.  The framework drives
the step loop and can call each env's `step` in sequence.

`start`-based environments (e.g. a future JS/browser env) have no step
loop -- the external runtime drives events.  There is no place for the
framework to call secondary steps.  Therefore `start`-based envs cannot
participate in multi-env and should declare `mode = nil`.

### Example: IUP + socket

```lua
require "atmos.env.iup"       -- primary: bounded blocking, clock via timer
require "atmos.env.socket"    -- secondary: non-blocking select, no clock

loop(function ()
    -- IUP drives the loop timing
    -- socket polls each iteration (instant)
    -- clock events come from IUP's timer only
end)
```

Previously this required manual env composition (see `iup/exs/iup-net.lua`).
With `mode`, it works automatically.
