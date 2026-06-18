# Plan: hoist streams worker prototypes into a lazy cache

## Status

DEFERRED -- not fixing now; the whole suite passes with the current
inline `task(f)` wrapping.
Tracked separately from the `task`/`xtask` sweep (`260616-task-xtask`).

## Context

After the `task`/`xtask` split, `atmos/streams.lua` spawns its internal
worker tasks by wrapping a raw function in a prototype at every spawn:

| site (approx) | call                                |
|---------------|-------------------------------------|
| fr_spawn      | `spawn(task(t.T), ...)`         |
| S.debounce    | `spawn(task(S.Debounce), ...)`  |
| S.buffer      | `spawn(task(S.Buffer), ...)`    |
| S.par/paror   | `spawn_in(tsks, task(T), ...)`       |
| TT            | `spawn_in(tsks, task(T), ...)`       |
| S.xpar/xparor | `spawn(task(TT), ...)`          |

`T`, `TT`, `S.Debounce`, `S.Buffer` are fixed module functions
instantiated repeatedly (`T` once per source in the `par` loop, and
again per source inside `TT`). Each spawn builds a throwaway prototype.

## Problem

A prototype should be built once and reused (it exists to be
instantiated many times). The obvious hoist --
`local Tp = task(T)` at module level -- does not work.

## Why module-level hoisting is impossible

The `task` global is not defined while `streams.lua` loads:

    init.lua  -- require "atmos.run"      (globals not set yet)
      run.lua   -- require "atmos.streams"  <-- streams body runs HERE
        streams.lua                          (task == nil)
    init.lua  -- task = ...                 (globals set AFTER)

Verified: after `require "atmos.run"`, `_G.task` is `nil`; it only
appears after `require "atmos"` completes.

Requiring it does not help either:

- `require "atmos.run"` from `streams.lua` is circular (`run.lua`
  requires `streams` first), so it recurses.
- `run.task` is defined later in `run.lua` -- absent at that point.
- A lazy `require` only yields `task` at runtime, same as the global
  we already call inline. Neither gives `task` at module-load time.

So one-prototype-per-worker requires lazy (first-use) construction.

## Proposed fix: lazy memoized prototype cache

Add near the top of `streams.lua` (after `N()`):

    -- prototypes built lazily and cached: the `task` global is not yet
    -- defined while this module loads (run.lua requires it before
    -- init.lua installs the globals), so `task(f)` cannot run at module
    -- level.
    local protos = setmetatable({}, {
        __mode  = 'k',   -- weak keys: per-call user fns (fr_spawn) GC
        __index = function (t, f)
            local p = task(f)
            rawset(t, f, p)
            return p
        end,
    })

Then replace each `task(f)` spawn argument with `protos[f]`:

| site        | from                  | to                |
|-------------|-----------------------|-------------------|
| fr_spawn    | `task(t.T)`            | `protos[t.T]`     |
| S.debounce  | `task(S.Debounce)`     | `protos[S.Debounce]` |
| S.buffer    | `task(S.Buffer)`       | `protos[S.Buffer]`   |
| TT, par,    | `task(T)`              | `protos[T]`       |
| paror       |                       |                   |
| xpar,xparor | `task(TT)`             | `protos[TT]`      |

## Notes

- `T`/`TT`/`Debounce`/`Buffer` -> one reused prototype each.
- Weak keys make per-call user functions (`fr_spawn`'s `t.T`)
  collectable; Lua 5.4 resolves the ephemeron (value `p` references
  key `f`) correctly, so no leak.
- Staying on the global `task` (via the cache) is consistent with the
  rest of `streams.lua`, which already pulls `spawn`/`await`/`emit_in`/
  `par_or`/`tasks` from globals.

## Steps

1. add the `protos` cache after `N()`.
2. swap the 7 `task(f)` spawn args to `protos[f]`.
3. run the streams suite; behaviour must be unchanged.
