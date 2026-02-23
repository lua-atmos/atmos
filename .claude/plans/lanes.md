# xtask / xspawn (LuaLanes)

Run a Lua function in a real OS thread via LuaLanes, then poll for its result
inside the atmos cooperative scheduler.

## Status: done

## Problem

Atmos uses cooperative concurrency — coroutines scheduled by a single-threaded
event loop.  This works well for I/O-bound and event-driven code, but **cannot
exploit multiple CPU cores**.  A CPU-heavy computation blocks the entire
scheduler until it returns.

`xtask`/`xspawn` solve this by offloading a function to a **real OS thread**
(via LuaLanes), while the atmos scheduler continues running other tasks.  The
calling task polls for the result via `await(true)` and resumes when the lane
finishes.

## Why serialization is needed

LuaLanes runs each lane in a **separate Lua state** (separate VM instance).
When a function and its arguments cross into a lane, they must be **copied**
into the new state.  This is serialization:

- **Functions**: Lanes calls `string.dump` internally on the function's
  bytecode.  Upvalues that are themselves serializable (numbers, strings,
  booleans, tables of those, other dumpable functions) are captured and
  transferred.  Non-serializable upvalues (C functions, userdata, threads)
  cause a Lanes error.
- **Arguments**: Tables are deep-copied by value.  Mutations inside the lane
  do not affect the parent.  Numbers, strings, booleans pass directly.
- **Return values**: Sent back through a `linda` (thread-safe message queue).
  Same serialization rules apply — the result table is deep-copied back.
- **Errors**: Error objects may not be serializable (e.g. tables with
  metatables, userdata).  We `tostring()` errors before sending them back
  through the linda.

### What Lanes handles automatically

The current implementation **lets Lanes handle function serialization
directly** — we pass the function `f` itself to `lanes.gen("*", ...)` as a
closure, and Lanes serializes it (bytecode + upvalues) internally.  There is
no manual `string.dump` / `load` step.

This means:
- Pure functions work.
- Functions capturing serializable upvalues (numbers, strings, tables, other
  pure functions) work — Lanes transfers them automatically.
- Functions capturing non-serializable upvalues (C functions, coroutines,
  userdata) fail with a Lanes error at lane creation time.

## Design: mirrors task/spawn

The API mirrors the existing `task`/`spawn` pattern:

| Pattern | Creates prototype | Executes |
|---------|------------------|----------|
| `task(f)` / `spawn(t, ...)` | coroutine-based task | runs in same Lua state |
| `xtask(f)` / `xspawn(xt, ...)` | lanes.gen-based prototype | runs in separate OS thread |

Like `spawn(f, ...)`, `xspawn(f, ...)` is a shorthand that creates and
immediately runs an xtask.

### `xtask(f)` — create a reusable prototype

```lua
function M.xtask (f)
    assertn(2, type(f) == 'function', "invalid xtask : expected function")
    return setmetatable({
        gen = lanes.gen("*", function (linda, ...)
            local r = table.pack(pcall(f, ...))
            if r[1] then
                linda:send("ok", { true, table.unpack(r, 2, r.n) })
            else
                linda:send("ok", { false, tostring(r[2]) })
            end
        end)
    }, meta_xtask)
end
```

`lanes.gen("*", wrapper)` compiles a lane prototype that:
1. Imports all standard libraries (`"*"`)
2. Wraps `f` in `pcall` to catch errors
3. Sends results (or stringified error) back through a linda

The function `f` is captured as an upvalue of the wrapper.  Lanes serializes
both the wrapper bytecode and `f` (as a sub-upvalue) when the lane launches.

### `xspawn(xt, ...)` — launch and poll

```lua
function M.xspawn (xt, ...)
    if type(xt) == 'function' then
        xt = M.xtask(xt)
    end
    assertn(2, getmetatable(xt) == meta_xtask, "invalid xspawn : expected xtask prototype")

    local me = M.me(true)
    assertn(2, me, "invalid xspawn : expected enclosing task")

    local linda = lanes.linda()
    local lane = assert(xt.gen(linda, ...))
    local _ <close> = M.defer(function ()
        pcall(function () lane:cancel(0, true) end)
    end)

    while true do
        local key, r = linda:receive(0, "ok")
        if key then
            if r[1] then
                return table.unpack(r, 2)
            else
                error(r[2], 0)
            end
        end
        M.await(true)
    end
end
```

Polling loop:
1. Creates a fresh `linda` (thread-safe queue) per spawn
2. Launches the lane with `xt.gen(linda, ...)`
3. Registers a `<close>` defer to cancel the lane if the parent task aborts
4. Polls `linda:receive(0, "ok")` (non-blocking) each scheduler tick
5. On result: unpacks return values or re-raises the stringified error

### Heartbeat (scheduler support)

When no environments are registered (e.g. tests without `require "atmos.env.clock"`),
the main loop has no event source.  Without events, `await(true)` never wakes
because nothing fires `emit`.

Fix: the loop emits a synthetic heartbeat when `#_envs_ == 0`:

```lua
-- in M.loop, after env.step() calls:
if #_envs_ == 0 then
    M.emit(false, nil, true)
end
```

This ensures `xspawn`'s `await(true)` gets a chance to check the linda each
iteration.

## Key decisions

| Decision | Choice | Why |
|----------|--------|-----|
| API naming | `xtask`/`xspawn` | mirrors `task`/`spawn`; "x" = cross-thread |
| Serialization | let Lanes handle it | no manual `string.dump`; upvalues transfer automatically |
| Result channel | `linda:send("ok", {bool, ...})` | table wrapper avoids multi-value send issues |
| Library imports | `"*"` (all) | avoids surprises when lane code uses any stdlib |
| Error serialization | `tostring(err)` on send side | error objects can't cross lane boundaries |
| Defer placement | after `xt.gen(...)` call | `lane` is always set, no nil guard needed |
| Cancel strategy | `lane:cancel(0, true)` in `pcall` | immediate soft-cancel; pcall absorbs if lane already finished |
| Polling | `linda:receive(0, "ok")` + `await(true)` | non-blocking check, yields to scheduler between polls |
| Heartbeat | `emit(false, nil, true)` when no envs | keeps polling alive in env-less tests |

## Upvalue support

Unlike the earlier `thread` design which **rejected** functions with upvalues
(via `debug.getupvalue` checks), `xtask`/`xspawn` **allows** them — Lanes
serializes upvalues automatically when they are serializable types:

| Upvalue type | Works? | Example |
|-------------|--------|---------|
| number, string, boolean | yes | `local x = 42; xspawn(function() return x end)` |
| table (of serializable values) | yes | deep-copied into lane |
| pure Lua function | yes | `local f = function(n) return n*2 end` |
| C function, userdata, thread | no | Lanes error at lane creation |

This is tested in `tst/thread.lua` tests 9-10.

## Files modified

| File | Change |
|------|--------|
| `atmos/run.lua` | `require("lanes").configure()` at top; `M.xtask`/`M.xspawn` section; heartbeat in `M.loop` |
| `atmos/init.lua` | `xtask = run.xtask` / `xspawn = run.xspawn` globals |
| `tst/thread.lua` | 17 tests covering errors, basic usage, upvalues, error propagation, lifecycle, isolation, prototype reuse |
| `tst/all.lua` | `dofile "thread.lua"` entry |
| `.github/workflows/test.yml` | `liblua5.4-dev` + `luarocks install lanes` |

## Tests (`tst/thread.lua`)

### Error tests
- xspawn 1: no enclosing task
- xspawn 2: no body function (passes non-function)
- xtask 1: no function argument

### Basic tests
- xspawn 3: no return value
- xspawn 4: return value
- xspawn 5: copied value parameters
- xspawn 6: table parameter (deep-copied)
- xspawn 7: string library available in lane
- xspawn 8: math library available in lane

### Upvalue tests
- xspawn 9: captures a pure function upvalue
- xspawn 10: captures a value upvalue

### Error propagation
- xspawn 11: error inside lane propagates to parent

### Lifecycle
- xspawn 12: parent task suspends during xspawn
- xspawn 13: sequential xspawns
- xspawn 14: xspawn inside par_or

### Isolation
- xspawn 15: table mutation in lane does not affect parent

### Prototype reuse
- xtask 2: reuse same prototype for multiple xspawns
- xtask 3: prototype captures upvalue

## Evolution

The implementation went through several iterations:

1. **`thread` with manual `string.dump`**: manually dumped bytecode, rejected
   all upvalues via `debug.getupvalue` check, loaded bytecode inside lane
   with `load()`.

2. **`thread` with synchronous isolation**: attempted to run "in-process"
   without Lanes for simplicity, but lost real parallelism.

3. **`xtask`/`xspawn` (current)**: renamed to mirror `task`/`spawn`, lets
   Lanes handle function serialization directly (no manual bytecode step),
   supports serializable upvalues naturally.

### Bug: polling loop hangs in bare `loop()` (resolved)

During the `thread` iteration, the polling loop hung when no envs
were registered.  Root cause:

```
loop(body)
  -> spawn(body)
    -> coroutine.resume(body)
      -> thread(f)
        -> lane launched (separate OS thread)
        -> linda:receive(0, "ok") — lane not done yet
        -> M.await(true) — yields coroutine
      <- coroutine returns (suspended)
  -> while true do
       coroutine.status(t._.th) == 'suspended'
       for _, env in ipairs(_envs_) do  -- EMPTY
       end
       -- loops forever, nobody resumes the coroutine
     end

Meanwhile, lane OS thread:
  -> pcall(f), linda:send("ok", true) — done
  (but nobody resumes the main coroutine)
```

`await(true)` yields and relies on `emit(...)` to resume.
With no envs, no `env.step()` runs, no events fire, and the
coroutine stays suspended forever — even though the lane has
already posted its result to the linda.

Fix: the heartbeat (`emit(false, nil, true)` when `#_envs_ == 0`)
described in the Heartbeat section above.

### CI/CD (`.github/workflows/test.yml`)

```yaml
- name: Install Lua
  run: |
    sudo apt-get update
    sudo apt-get install -y lua5.4 luarocks
- name: Install LuaLanes
  run: sudo luarocks install lanes
- name: Run tests
  run: |
    eval $(luarocks path)
    cd tst && LUA_PATH="...;;$LUA_PATH" lua5.4 all.lua
```
