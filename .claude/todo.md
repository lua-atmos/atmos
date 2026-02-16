# TODO: Remove debug_getinfo workaround

## Problem

`debug_getinfo` in `util.lua` is a wrapper around `debug.getinfo` that adds a
nil fallback (`{ short_src='?', currentline='?' }`). This masks bugs instead of
failing cleanly — when the stack level is wrong, you silently get `?:?` in error
traces instead of a crash.

## Current state

After commit b3a77b3, `init.lua` was changed from `debug.getinfo(2)` to
`debug_getinfo(2)` to fix a nil crash when `spawn` runs as a coroutine entry
point. This fixed the symptom but is the same workaround pattern.

## Call sites

### `init.lua` — user-facing globals (task, spawn, spawn_in)

All use `debug_getinfo(2)` to capture the caller. Level 2 is correct when
called from user code, but nil when the function is the coroutine entry point
(e.g. `loop(spawn, f)`).

- `init.lua:27,29` — `task()`
- `init.lua:34` — `spawn_in()`
- `init.lua:39,41` — `spawn()`

### `run.lua` — level 2 calls (safe)

These are all internal functions called from user code inside tasks. Level 2
(the caller) always exists. No fallback needed.

- `run.lua:231` — `run.throw()`
- `run.lua:347` — `run.loop()` — dbg for xcall error trace
- `run.lua:379` — `run.start()`
- `run.lua:388` — `run.tasks()`
- `run.lua:786` — `run.emit()`
- `run.lua:802,803` — `run.toggle()`
- `run.lua:853,864,875` — `run.par()`, `run.par_or()`, `run.par_and()`
- `run.lua:885` — `run.watching()`

### `run.lua:354` — level 4 call (fragile)

```lua
-- inside run.loop, inside a closure passed to xcall/pcall:
local t <close> = run.spawn(debug_getinfo(4), nil, false, body, ...)
```

This reaches through: closure(1) -> pcall(2) -> xcall(3) -> run.loop(4).
Gets `run.loop` itself, which is intentional (the caller of loop is separately
captured at line 347). But if xcall internals change, the level breaks silently.

## Proper fix

1. **Remove `debug_getinfo` wrapper entirely** — go back to raw `debug.getinfo`
   everywhere so wrong levels crash instead of producing `?:?`.

2. **Fix `init.lua`** — the user-facing globals should not need a fallback.
   Either:
   - (a) Pass dbg info as a coroutine argument from `run.loop`/`run.spawn`
     down to the body, so functions like `spawn` don't need to look up the
     stack at all when running as a coroutine entry point.
   - (b) Document that passing `spawn` directly as a loop body is not
     supported, and fix the test to use `loop(function() spawn(f) end)`.

3. **Fix `run.lua:354`** — capture debug info in `run.loop` before entering
   xcall, and pass it to the closure via upvalue. Eliminates the fragile
   level 4 lookup.
