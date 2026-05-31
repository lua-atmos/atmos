# Plan: await(ts, :any | :all)

Add an optional 2nd argument `:any` / `:all` to `await(ts)`.
`:any` reshapes the return to `ret, t, ts`;
`:all` waits for the pool to drain and returns just `ts`.

## Decisions

| # | Topic        | Decision                                            |
|---|--------------|-----------------------------------------------------|
| 1 | Arg mode     | Optional; **default `:any`**. `:all` opts in.       |
| 2 | `:any` ret   | `ret, t, ts` (first task to terminate).             |
| 3 | `:all` ret   | just `ts`, once the pool has fully drained.         |
| 4 | Empty pool   | `:any` -> `nil, nil, ts`; `:all` -> `ts`.           |
| 5 | `:all` members | dynamic: waits until the pool empties, including tasks spawned mid-wait. |
| 6 | `:all` impl  | drain-emit: `task_gc` emits `(ts,'all')` when the pool empties; routed by `_is_`, no loop. |
| 7 | Scope        | core + `api.md` + migrate existing pool-await call sites. |

## Return signatures

    await(t)             ->  ret, t          ;; task + its return
    await(ts)            ->  ret, t, ts      ;; :any (default), first to end
    await(ts, :any)      ->  ret, t, ts
    await(ts, :all)      ->  ts              ;; after the pool drains
    await(<empty>, :any) ->  nil, nil, ts
    await(<empty>, :all) ->  ts

## Mechanism (how it routes)

- mode is positional in the pattern: `T = {'==', ts, mode}`.
- the pool emits two tagged events to its parent scope:
    - per task death (`task_result`): `emit(ts, 'any', t)`
    - on drain (`task_gc`, when `#ts==0`, skipping root TASKS):
      `emit(ts, 'all')`
- `check_ret`'s `_is_` loop matches the emit tag against `T[3]`:
    - `:any` awaiter matches `'any'` death emits -> `ret, t, ts`
    - `:all` awaiter matches `'all'` drain emit  -> `ts`
  so coexisting `:any` / `:all` awaiters each pick their own events.
- `await(t)` (single task) returns `ret, t` (via `check_ret` /
  `check_task_ret`, with the task as 2nd value).

## Implementation steps

1. **Parse mode** — `await_to_table` pool branch:
   `mode = (...) or 'any'`, assert `any|all`, `T = {'==', e, mode}`.

2. **Empty-pool short-circuit** (`M.await`, after `await_to_table`):
   if pool and `#ts==0`, return mode-aware
   (`:any` -> `nil,nil,ts`, `:all` -> `ts`).

3. **`:any` return** (`check_ret` pool branch): `ret, t, ts`.

4. **`:all` via drain-emit**:
   - tag death emits `'any'`; add a `'all'` drain emit in `task_gc`.
   - `check_ret` returns `ts` on the `'all'` match; `:all` ignores
     deaths (`'any'`-tagged, do not match `'all'`).

5. **Docs** — `api.md` await table (mode arg + return shapes).

6. **Migrate call sites** — `await(t)` now `ret,t` and `await(ts)` now
   `ret,t,ts`; updated `tst/` (tasks 1, task combinators or/and) and
   `atmos/streams.lua` `paror`.

## Open / to confirm

- (resolved) invalid mode -> `"invalid await : expected :any or :all"`.
- (resolved) spelling `:any` / `:all`.

## Progress

- [x] Semantics decided (decisions table above)
- [x] Step 1: parse mode arg (await_to_table, T[3]=mode, default :any, assert)
- [x] Step 2: empty-pool short-circuit (mode-aware: :any nil,nil,ts / :all ts)
- [x] Step 3: :any return reshape (check_ret pool branch -> ret,t,ts)
- [x] Step 4: :all waits for the drain-emit (task_gc emits (ts,'all')),
      returns ts; :any unchanged
- [x] Step 5: api.md docs (mode arg + return shapes)
- [x] Step 6: migrate call sites (await(t)->ret,t, await(ts)->ret,t,ts;
      tst + streams.lua paror)
