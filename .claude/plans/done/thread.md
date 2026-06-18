# thread (LuaLanes)

Run a Lua function in a real OS thread via LuaLanes, then poll
for its result inside the atmos cooperative scheduler.

## Status: done

## Problem

Atmos uses cooperative concurrency — coroutines scheduled by a
single-threaded event loop. This works well for I/O-bound and
event-driven code, but **cannot exploit multiple CPU cores**. A
CPU-heavy computation blocks the entire scheduler until it
returns.

`thread` solves this by offloading a function to a **real OS
thread** (via LuaLanes), while the atmos scheduler continues
running other tasks. The calling task polls for the result via
`await(true)` and resumes when the lane finishes.

## API: `thread(args..., f)`

Single inline blocking call — args first, body function last:

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

## Why serialization is needed

LuaLanes runs each lane in a **separate Lua state** (separate
VM instance). When a function and its arguments cross into a
lane, they must be **copied** into the new state:

- **Functions**: Lanes calls `string.dump` internally. Upvalues
  that are serializable (numbers, strings, booleans, tables of
  those, other dumpable functions) are captured and transferred.
  Non-serializable upvalues (C functions, userdata, threads)
  cause a Lanes error.
- **Arguments**: Tables are deep-copied by value. Mutations
  inside the lane do not affect the parent.
- **Return values**: Sent back through a `linda` (thread-safe
  message queue). Same serialization rules apply.
- **Errors**: Error objects may not be serializable. We
  `tostring()` errors before sending them back through linda.

The implementation **lets Lanes handle function serialization
directly** — we pass `f` as an upvalue of a wrapper closure to
`lanes.gen("*", ...)`, and Lanes serializes it (bytecode +
upvalues) internally at lane launch time. No manual
`string.dump` / `load` step.

## Implementation (`atmos/run.lua`)

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

`lanes.gen("*", wrapper)` records the function prototype. The
wrapper captures `f` as an upvalue. Serialization of `f` (its
bytecode + upvalues) happens at **lane launch time**
(`gen(linda, ...)`), NOT at gen creation time. So a cached gen
correctly picks up updated upvalue values on later calls.

Cache key is function **identity** (same Lua object = hit).
Weak keys (`__mode = 'k'`) ensure no memory leak — if `f` is
garbage collected, the cached gen entry disappears.

## Upvalue support

Unlike the earlier design which rejected functions with
upvalues (via `debug.getupvalue` checks), the current
implementation allows them — Lanes serializes upvalues
automatically when they are serializable types:

| Upvalue type | Works? |
|---|---|
| number, string, boolean | yes |
| table (of serializable values) | yes (deep-copied) |
| pure Lua function | yes |
| C function, userdata, thread | no (Lanes error) |

## Key decisions

| Decision | Choice | Why |
|----------|--------|-----|
| API | `thread(args..., f)` | inline like `do{...}`, single concept |
| Serialization | let Lanes handle it | no manual `string.dump`; upvalues transfer automatically |
| Result channel | `linda:send("ok", {bool, ...})` | table wrapper avoids multi-value send issues |
| Library imports | `"*"` (all) | avoids surprises when lane code uses any stdlib |
| Error serialization | `tostring(err)` on send side | error objects can't cross lane boundaries |
| Cancel strategy | `lane:cancel(0, true)` in `pcall` | immediate soft-cancel; pcall absorbs if lane already finished |
| Polling | `linda:receive(0, "ok")` + `await(true)` | non-blocking check, yields to scheduler between polls |
| Caching | weak-key table by function identity | avoids repeated `lanes.gen` for same function |
| Lazy require | `lanes` loaded on first `thread` call | no penalty for programs that never use threads |

## Files modified

| File | Change |
|------|--------|
| `atmos/run.lua` | lazy `local lanes`; `_gen_cache` + `M.thread` |
| `atmos/init.lua` | `thread = run.thread` |
| `tst/thread.lua` | 17 tests |
| `tst/all.lua` | `dofile "thread.lua"` entry |
| `.github/workflows/test.yml` | `liblua5.4-dev` + `luarocks install lanes` |

## Tests (`tst/thread.lua`)

All tests use `spawn` + `os.execute("sleep 0.1")` + `emit()`
pattern (no `loop`, no environment).

| # | Category | Description |
|---|----------|-------------|
| 1 | error | no enclosing task |
| 2 | error | no body function |
| 3 | basic | no return value |
| 4 | basic | return value |
| 5 | params | copied values |
| 6 | params | table (deep-copied) |
| 7 | params | string lib available in lane |
| 8 | params | math lib available in lane |
| 9 | upvalue | captures pure function |
| 10 | upvalue | captures value |
| 11 | error | error inside lane propagates |
| 12 | lifecycle | parent suspends during thread |
| 13 | lifecycle | sequential threads |
| 14 | lifecycle | thread inside par_or |
| 15 | isolation | table mutation doesn't cross |
| 16 | reuse | same fn, multiple calls |
| 17 | cache | cache hit with updated upvalue |

## Evolution

1. **`thread` with manual `string.dump`** — manually dumped
   bytecode, rejected all upvalues via `debug.getupvalue`
   check, loaded bytecode inside lane with `load()`. The
   polling loop (`await(true)`) hung in bare `loop()` with no
   envs because no `env.step()` would run to emit events and
   resume the coroutine. Fixed by using `spawn` + `emit()`
   test pattern instead.

2. **`xtask`/`xspawn` handles** — renamed to mirror
   `task`/`spawn`, let Lanes handle function serialization,
   supported serializable upvalues naturally. Two-concept API
   (factory + launcher). Removed because the inline `thread`
   approach is simpler — single function, single concept, no
   handle/await asymmetry.

3. **`thread` with gen caching (current)** — simplified back
   to single inline `thread(args..., f)` API, with `lanes.gen`
   cached by function identity in a weak-key table. Lazy
   `require("lanes")`. Removed `xtask`/`xspawn`.

## TODO

- `xemit`, `xawait`, `xchannel(linda)` for inter-thread
  communication
