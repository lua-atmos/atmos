# thread-noawait

Threads cannot use structured concurrency mechanisms — in
particular, they all lead to `await` which should be forbidden
**inside the lane body**.

## Status: done

## Resolution

No code changes needed in `atmos/run.lua`. The existing guard
in `M.await` already covers this:

```lua
local t = M.me(true)
assertn(2, t, "invalid await : expected enclosing task", 2)
```

Inside a lane (separate Lua state), `coroutine.running()`
returns `nil`, so `M.me(true)` returns `nil`, and the assertion
fires. All structured concurrency functions (`par`, `par_or`,
`par_and`, `watching`, `every`, `toggle`) also check
`M.me(true)` at the top.

In practice, the globals (`await`, `spawn`, etc.) don't even
exist in the lane's Lua state — calling them gives "attempt to
call a nil value".

## Tests added

| # | Description |
|---|-------------|
| 18 | `await` forbidden inside thread |
| 19 | `spawn` forbidden inside thread |
| 20 | `par_or` forbidden inside thread |

## Files

| File | Change |
|------|--------|
| `tst/thread.lua` | 3 new tests (18-20) |
