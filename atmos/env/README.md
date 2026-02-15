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

### Full environment table

| Callback   | Description                                  |
|------------|----------------------------------------------|
| `open()`   | Initialize/re-initialize resources           |
| `step()`   | Poll once for external events, emit them     |
| `close()`  | Cleanup resources                            |

`open` and `close` are symmetric: `open` is called at the start of
`loop`/`start`, `close` at the end. This allows multiple `loop()`
invocations within the same process -- each call re-initializes via
`open` and tears down via `close`.

`loop` uses `step` to drive the event loop. `start` does not --
the environment itself drives events (e.g. JS browser callbacks).

### Teardown: `close` vs `stop`

- `close()` kills all tasks (running their `<close>` handlers)
- `stop()` does full teardown: `close()` first, then `_env_.close()`

Tasks are closed before the environment so that task cleanup code
(defers, `<close>` handlers) can still use environment resources.

`loop` calls `stop()` automatically when the step loop exits.
`start` does not -- the environment backend must call `stop()` at the
appropriate time (e.g. JS `beforeunload` listener).

### Which environments use what

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
