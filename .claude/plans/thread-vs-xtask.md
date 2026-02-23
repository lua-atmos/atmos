# thread vs xtask — API comparison

## Status: resolved — `thread` chosen

## Two approaches to OS threads in atmos

### A. Inline `thread` (chosen)

```lua
-- blocks current task, returns result inline
local result = thread(arg1, arg2, function (a1, a2)
    return heavy_computation(a1, a2)
end)
```

- Single function, single concept
- Last argument is the body function
- Blocks the calling task (via `await(true)` polling)
- No handle, no separate await, no __close
- Cleanup via `defer` inside the function scope
- `lanes.gen` cached by function identity for reuse

**Pros**: simple API, one concept, inline like `do{...}`
**Cons**: no non-blocking usage, can't launch multiple in
parallel from the same task

### B. `xtask`/`xspawn` handles (removed)

```lua
local xt = xtask(function (n) return n * n end)
local h = xspawn(xt, 10)   -- returns handle immediately
-- ... do other stuff ...
local result = await(h)     -- wait for completion
```

- Two functions: `xtask` (factory) + `xspawn` (launcher)
- `xspawn` returns handle immediately (non-blocking)
- `await(h)` waits for result
- `h <close>` cancels the lane
- Prototype reuse: `xtask` once, `xspawn` many times

**Pros**: non-blocking, parallel launches, __close, await
**Cons**: two-concept API, asymmetric with task/spawn
mapping (task IS the handle, xtask is NOT)

## Mapping comparison

| | task world | thread (A) | xtask (B) |
|---|---|---|---|
| create | `task(f)` | — | `xtask(f)` (factory) |
| execute | `spawn(t, ...)` | `thread(args, f)` | `xspawn(xt, ...)` |
| result | `await(t)` | inline return | `await(h)` |
| cancel | `t <close>` | scope-based defer | `h <close>` |
| reuse | no (task is single-use) | cache-based | explicit prototype |

## Decision

`thread` was chosen for simplicity. The inline blocking
pattern covers the primary use case (offload CPU work). For
future non-blocking parallel lanes, `xemit`/`xawait`/
`xchannel(linda)` will be added on top.
