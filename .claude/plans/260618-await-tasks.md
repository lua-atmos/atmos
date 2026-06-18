# Plan: reject bare `await(ts)` — require `:any` / `:all`

## Goal

A task pool has two distinct termination semantics, so awaiting a bare pool
is ambiguous and must be a hard error, not a silent hang.

| form      | meaning          | returns  |
|-----------|------------------|----------|
| `:any ts` | first task ends  | `v,t,ts` |
| `:all ts` | pool drains      | `ts`     |
| `ts`      | ambiguous        | ERROR    |

A single task `await(t)` stays valid: it has only one meaning (`t` ends).

## Diagnosis

A pool from `M.tasks()` has metatable `meta_tasks` (`run.lua:36`) and no
`.tag`.
With a bare `await(ts)`:

- `tag = (type(awt)=='table' and awt.tag) or awt` resolves to the table
  itself (no `.tag`).
- no branch matches (`or`/`and`/`not`/`until`/`while`/`tasks`/`clock`/
  task/func).
- `meta_tasks` has no `__atmos`, so the match loop (`run.lua:536`) just
  `coroutine.yield()`s forever -> silent hang.

Pools are only handled via the `{tag='tasks', mode=…, tasks=ts}` wrapper
(`run.lua:542`) that `:any` / `:all` produce.

Must be a RUNTIME guard: `ts` is a runtime value, so the compiler cannot
know an expression is a pool and reject it statically.

## Change

`run.lua`, in `M.await`, right after the `me` assert (~`:469`), before the
`tag` computation:

```lua
    local me = M.me(true)
    assertn(2, me, "invalid await : expected enclosing task")

    -- a bare pool has metatable meta_tasks and no .tag: it would never
    -- match and hang; require :any / :all to await a pool
    assertn(2, getmetatable(awt) ~= meta_tasks,
        "invalid await : expected ':any' or ':all' for a task pool"
    )
```

- `meta_tasks` is the local at `run.lua:36` (in scope).
- only converts a hang into an explicit error; no valid await changes.

## Verify

- existing suite stays green.
- `await(M.tasks())` now raises
  `invalid await : expected ':any' or ':all' for a task pool`.

## Status

- [ ] add the `meta_tasks` guard in `M.await`.
- [ ] run the suite; confirm bare-pool error + no regressions.

## Cross-refs

- atmos-lang tracker: `atmos/.claude/plans/06-11-await.md` (REMAINING item
  "bare-pool guard"); design confirmed there.
