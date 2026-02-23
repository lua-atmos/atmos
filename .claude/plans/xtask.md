# Non-blocking xspawn with custom xtask handle

## Status: superseded by `thread` (see lanes.md)

The `xtask`/`xspawn` handle-based design was replaced by the
simpler inline `thread(args..., f)` API with `lanes.gen`
caching. See `lanes.md` for the current implementation.

## Original goal

Make xtask/xspawn behave like task/spawn:
1. `xspawn` returns a handle immediately (non-blocking)
2. `await(handle)` waits for lane completion
3. `handle <close>` cancels the lane via `__close`
4. `require("lanes")` is lazy (inside `xtask`)

## Why superseded

The inline `thread` approach is simpler:
- Single function, single concept (no factory + launcher)
- No handle/await asymmetry with task/spawn
- Caching via weak-key table replaces explicit prototypes
- Inline blocking matches the common use case

For non-blocking parallel lane launches, the future
`xemit`/`xawait`/`xchannel(linda)` API will provide that
capability on top of `thread`.
