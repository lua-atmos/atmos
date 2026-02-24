# thread-cancel

Add tests for thread cancellation.

## Status: on hold (test 22 blocked)

## Description

Add tests that exercise the `defer`-based cancellation mechanism in
`M.thread` — when a parent task is closed (e.g. via `par_or` or
`watching`), the `<close>` on the defer fires `lane:cancel()`.
Tests should use `sleep` inside the lane body (to make it long-running)
and `defer` to verify cleanup.

## Tests (22 total)

| # | Section | Description | Status |
|---|---------|-------------|--------|
| 1–2 | ERRORS | Error cases (no task, no body) | pass |
| 3–8 | BASIC | No return, return value, upvalues, table copy, string/math | pass |
| 9–10 | UPVALUES | Pure function, value upvalue | pass |
| 11 | ERROR PROPAGATION | Error inside lane propagates | pass |
| 12–14 | LIFECYCLE | Suspend during thread, sequential, inside par_or | pass |
| 15 | ISOLATION | Table mutation isolation | pass |
| 16–17 | REUSE | Prototype reuse, cache hit with updated upvalue | pass |
| 18 | CANCEL | par_or cancels sleeping thread | pass |
| 19 | CANCEL | watching cancels sleeping thread | pass |
| 20 | CANCEL | parent death cancels thread | pass |
| 21 | CANCEL | defer fires inside lane body | pass |
| 22 | CANCEL | defer fires inside lane body on cancel | **FAIL** |

## Investigation: test 22

Test 22 expects `__close` metamethods to fire inside a LuaLanes
lane when the lane is cancelled. This does not work.

### Root cause

LuaLanes' hard cancel (`lane:cancel('hard', ...)`) installs
`lua_sethook` with `count=1`, meaning the hook fires at **every**
VM instruction. When the cancel error unwinds the stack:

1. `__close` handler is called
2. First VM instruction inside `__close` triggers the hook again
3. Hook throws another cancel error, interrupting `__close`
4. `__close` never completes any work

### What was tried

1. **Increase cancel timeout** (0 → 1 second): no effect. The
   lane terminates instantly but `__close` is still interrupted
   by the persistent count=1 hook.

2. **Expose linda to `f`** via `pcall(f, linda)`: allows the lane
   body to call `linda:receive(0)` as a cooperation point. However
   `linda:receive(0)` is non-blocking and does not serve as a
   cancellation point for LuaLanes.

3. **Disable hook after first fire** (`pcall(debug.sethook)` inside
   `__close`): impossible because the count=1 hook fires at the
   very first instruction of `__close`, before any code can execute.

### Cleanup is unreliable at two levels

- **Lua level**: `__close` handlers are interrupted by the
  persistent cancel hook (count=1).
- **C level**: hard cancel ultimately calls `pthread_cancel`, which
  does not guarantee C resource cleanup (open fds, malloc, etc.).

### Viable approach (not yet implemented)

Install a custom `debug.sethook` inside the lane wrapper
(count=10000) that periodically checks for a cancel signal on the
linda. When detected, the hook **removes itself** and throws a
**regular** Lua error. Since there is no persistent hook, `__close`
runs uninterrupted. LuaLanes' hard cancel is never called (or only
as a last-resort fallback for lanes stuck in C code).

```lua
-- in the gen wrapper:
debug.sethook(function ()
    if linda:receive(0, "cancel") then
        debug.sethook()
        error("thread:cancelled", 0)
    end
end, "", 10000)

-- in the defer: send signal, wait, fallback:
linda:send("cancel", true)
lane:join(1)
if lane.status ~= 'done' and lane.status ~= 'error' then
    lane:cancel('hard', 0, true, 1)
end
```

### Current changes

- `run.lua:837`: `pcall(f,linda)` — linda exposed to `f`
- `tst/thread.lua`: test 22 uses nested spawn + `linda:receive(0)`
- Test 22 is **not passing**

### GitHub issue

- #21 — threads: defer/C cleanup is unreliable with automatic
  abortion

## TODO

- [x] Write tests 18–22
- [ ] Run tests 1–21 (manual)
- [ ] Fix test 22 (blocked on cancel/cleanup approach)
