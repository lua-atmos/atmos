# Plan: debug.getinfo — Remove wrapper

## Goal

Remove the `debug_getinfo` wrapper from `atmos/util.lua` and replace
all usages with direct `debug.getinfo` calls.

## Status

- [x] Interview / clarify requirements
- [x] Explore all call sites
- [x] Plan the replacement strategy
- [x] Apply changes to `util.lua` — delete wrapper
- [x] Apply changes to `run.lua` — replace 13 call sites
- [x] Fix coroutine boundary issue in `run.loop` / `run.start`
- [x] Verify — all tests passing
- [ ] Commit / push / PR

## Key Insight

The wrapper adds `+1` to offset its own stack frame. Removing it
also removes the need for `+1`. Every `debug_getinfo(N)` becomes
`debug.getinfo(N)` — same N, no arithmetic change.

## Coroutine boundary fix

The old `run.call` wrapped `body` before spawning, which provided
an extra stack frame. The `run.call` → `run.loop` refactor (from
main merge) removed that wrapper. When a function like `spawn` is
passed directly as `body`, it runs as the coroutine entry point
with no caller frame, causing `debug.getinfo(2)` to return nil.

Fix: wrap `body` in a non-tail-call function in both `run.loop`
and `run.start`:
```lua
local body = function (...)
    return (function (...) return ... end)(body(...))
end
```
`body(...)` is an argument (not a tail call), so the wrapper stays
on the stack while `body` executes.

## Changes applied

### util.lua
- Deleted `debug_getinfo` function (was lines 25-27)

### run.lua — wrapper removal (13 sites)
| Line | Place              | Before              | After             |
|------|--------------------|----------------------|-------------------|
| 221  | `run.throw`        | `debug_getinfo(2)`   | `debug.getinfo(2)` |
| 340  | `run.loop`         | `debug_getinfo(2)`   | `debug.getinfo(2)` |
| 347  | `run.loop` (spawn) | `debug_getinfo(4)`   | `debug.getinfo(4)` |
| 372  | `run.start`        | `debug_getinfo(2)`   | `debug.getinfo(2)` |
| 391  | `run.tasks`        | `debug_getinfo(2)`   | `debug.getinfo(2)` |
| 789  | `run.emit`         | `debug_getinfo(2)`   | `debug.getinfo(2)` |
| 805  | `run.toggle` (1)   | `debug_getinfo(2)`   | `debug.getinfo(2)` |
| 806  | `run.toggle` (2)   | `debug_getinfo(2)`   | `debug.getinfo(2)` |
| 856  | `run.par`          | `debug_getinfo(2)`   | `debug.getinfo(2)` |
| 867  | `run.par_or`       | `debug_getinfo(2)`   | `debug.getinfo(2)` |
| 878  | `run.par_and`      | `debug_getinfo(2)`   | `debug.getinfo(2)` |
| 888  | `run.watching`     | `debug_getinfo(2)`   | `debug.getinfo(2)` |

### run.lua — body wrapping
| Line    | Place       | Description                              |
|---------|-------------|------------------------------------------|
| 337-339 | `run.loop`  | Wrap `body` in non-tail-call function    |
| 369-371 | `run.start` | Same wrapping for consistency            |

## Notes

- No linked GitHub issue
- `init.lua` already used `debug.getinfo` directly (not the wrapper)
