# thread (LuaLanes)

Run a Lua function in a real OS thread via LuaLanes, then poll for its result
inside the atmos cooperative scheduler.

## Status: done (replaced xtask/xspawn)

## Problem

Atmos uses cooperative concurrency — coroutines scheduled by a single-threaded
event loop.  This works well for I/O-bound and event-driven code, but **cannot
exploit multiple CPU cores**.  A CPU-heavy computation blocks the entire
scheduler until it returns.

`thread` solves this by offloading a function to a **real OS thread**
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

The implementation **lets Lanes handle function serialization directly** — we
pass the function `f` as an upvalue of a wrapper closure to `lanes.gen("*",
...)`, and Lanes serializes it (bytecode + upvalues) internally at lane launch
time.  There is no manual `string.dump` / `load` step.

This means:
- Pure functions work.
- Functions capturing serializable upvalues (numbers, strings, tables, other
  pure functions) work — Lanes transfers them automatically.
- Functions capturing non-serializable upvalues (C functions, coroutines,
  userdata) fail with a Lanes error at lane creation time.

## API: `thread(args..., f)`

Single inline blocking call — args come first, body function last:

```lua
local result = thread(10, 3, function (data, factor)
    return data * factor
end)
```

- Blocks the calling task (via `await(true)` polling)
- Returns the lane result inline
- No handle, no separate await, no __close
- Cleanup via `defer` inside the function scope
- `lanes.gen` cached by function identity (weak-key table)
- `require("lanes")` is lazy — first `thread` call triggers it

### Implementation (`atmos/run.lua`)

```lua
local _gen_cache = setmetatable({}, { __mode = 'k' })

function M.thread (...)
    local args = { ... }
    local f = table.remove(args)
    assertn(2, type(f)=='function',
        "invalid thread : expected body function")

    local me = M.me(true)
    assertn(2, me,
        "invalid thread : expected enclosing task")

    if not lanes then
        lanes = require("lanes").configure()
    end

    local gen = _gen_cache[f]
    if not gen then
        gen = lanes.gen("*", function (linda, ...)
            local r = table.pack(pcall(f, ...))
            if r[1] then
                linda:send("ok",
                    { true, table.unpack(r, 2, r.n) })
            else
                linda:send("ok",
                    { false, tostring(r[2]) })
            end
        end)
        _gen_cache[f] = gen
    end

    local linda = lanes.linda()
    local lane = assert(gen(linda, table.unpack(args)))
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

### Why caching is safe

`lanes.gen("*", wrapper)` records the function prototype. The wrapper captures
`f` as an upvalue. Serialization of `f` (its bytecode + upvalues) happens at
**lane launch time** (`gen(linda, ...)`), NOT at gen creation time. So a cached
gen correctly picks up updated upvalue values on later calls.

Cache key is function **identity** (same Lua object = cache hit). Weak keys
(`__mode = 'k'`) ensure no memory leak — if `f` is garbage collected, the
cached gen entry disappears automatically.

## Key decisions

| Decision | Choice | Why |
|----------|--------|-----|
| API | `thread(args..., f)` | inline like `do{...}`, single concept |
| Serialization | let Lanes handle it | no manual `string.dump`; upvalues transfer automatically |
| Result channel | `linda:send("ok", {bool, ...})` | table wrapper avoids multi-value send issues |
| Library imports | `"*"` (all) | avoids surprises when lane code uses any stdlib |
| Error serialization | `tostring(err)` on send side | error objects can't cross lane boundaries |
| Defer placement | after `gen(...)` call | `lane` is always set, no nil guard needed |
| Cancel strategy | `lane:cancel(0, true)` in `pcall` | immediate soft-cancel; pcall absorbs if lane already finished |
| Polling | `linda:receive(0, "ok")` + `await(true)` | non-blocking check, yields to scheduler between polls |
| Caching | weak-key table by function identity | avoids repeated `lanes.gen` for same function |
| Lazy require | `lanes` loaded on first `thread` call | no penalty for programs that never use threads |

## Upvalue support

Unlike the earlier `thread` design which **rejected** functions with upvalues
(via `debug.getupvalue` checks), the current implementation **allows** them —
Lanes serializes upvalues automatically when they are serializable types:

| Upvalue type | Works? | Example |
|-------------|--------|---------|
| number, string, boolean | yes | `local x = 42; thread(function() return x end)` |
| table (of serializable values) | yes | deep-copied into lane |
| pure Lua function | yes | `local f = function(n) return n*2 end` |
| C function, userdata, thread | no | Lanes error at lane creation |

This is tested in `tst/thread.lua` tests 9-10.

## Files modified

| File | Change |
|------|--------|
| `atmos/run.lua` | lazy `local lanes`; `_gen_cache` + `M.thread` replacing `meta_xtask`/`M.xtask`/`M.xspawn` |
| `atmos/init.lua` | `thread = run.thread` (removed `xtask`/`xspawn` globals) |
| `tst/thread.lua` | 17 tests covering errors, basic usage, upvalues, error propagation, lifecycle, isolation, reuse, cache |
| `tst/all.lua` | `dofile "thread.lua"` entry |
| `.github/workflows/test.yml` | `liblua5.4-dev` + `luarocks install lanes` |

## Tests (`tst/thread.lua`)

All tests use `spawn` + `os.execute("sleep 0.1")` + `emit()` pattern
(no `loop`, no environment).

### Error tests
- thread 1: no enclosing task
- thread 2: no body function (passes non-function)

### Basic tests
- thread 3: no return value
- thread 4: return value
- thread 5: copied value parameters
- thread 6: table parameter (deep-copied)
- thread 7: string library available in lane
- thread 8: math library available in lane

### Upvalue tests
- thread 9: captures a pure function upvalue
- thread 10: captures a value upvalue

### Error propagation
- thread 11: error inside lane propagates to parent

### Lifecycle
- thread 12: parent task suspends during thread
- thread 13: sequential threads (2x sleep+emit cycles)
- thread 14: thread inside par_or

### Isolation
- thread 15: table mutation in lane does not affect parent

### Reuse / Cache
- thread 16: prototype reuse (same fn, multiple calls)
- thread 17: cache hit with updated upvalue

## Evolution

The implementation went through several iterations:

1. **`thread` with manual `string.dump`**: manually dumped bytecode, rejected
   all upvalues via `debug.getupvalue` check, loaded bytecode inside lane
   with `load()`.

2. **`thread` with synchronous isolation**: attempted to run "in-process"
   without Lanes for simplicity, but lost real parallelism.

3. **`xtask`/`xspawn`**: renamed to mirror `task`/`spawn`, lets Lanes handle
   function serialization directly, supports serializable upvalues naturally.
   Two-concept API (factory + launcher).

4. **`thread` with gen caching (current)**: simplified back to single inline
   `thread(args..., f)` API, with `lanes.gen` cached by function identity in
   a weak-key table. Lazy `require("lanes")`. Removed `xtask`/`xspawn`.

## TODO

- `xemit`, `xawait`, `xchannel(linda)` for inter-thread communication

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
