# Plan: await(ts, :any | :all)

Add a 2nd argument `:any` / `:all` to `await(ts)` and reshape its
return value to be `ret`-first, consistent with `await(t)`.

## Decisions

| # | Topic        | Decision                                            |
|---|--------------|-----------------------------------------------------|
| 1 | Arg mode     | Optional; **default `:any`**. `:all` opts in.       |
| 2 | `:any` ret   | `ret, t, ts` (first task to terminate).             |
| 3 | `:all` ret   | `ret, t, ts` (**last** task to terminate).          |
| 4 | Empty pool   | Both modes return immediately `nil, nil, ts`.       |
| 5 | `:all` membership | Dynamic: wait until `#ts == 0`, counts tasks spawned mid-wait. |
| 6 | `:all` impl  | **Native in `run.lua`** (not prelude sugar).        |
| 7 | Scope        | Core + `api.md` + migrate all existing `await(ts)` call sites. |

## Target return signatures

    await(t)            ->  ret
    await(ts)           ->  ret, t, ts     ;; :any (default)
    await(ts, :any)     ->  ret, t, ts     ;; first to terminate
    await(ts, :all)     ->  ret, t, ts     ;; last  to terminate
    await(<empty> ts ..)->  nil, nil, ts

## Mechanism recap (how death is signaled/captured)

- On death, `task_result` (run.lua:159-187) sets `t.ret` then
  emits the task as event tag; pooled tasks also emit `(ts, t)`.
- `await` builds `T = {'==', e, ...}` (await_to_table:603),
  suspends, and `check_ret` (run.lua:534) matches by metatable.
- Pool match today: `run.lua:567-569` returns `t, ts` (inverted).

## Implementation steps

1. **Parse mode arg**
   - `await_to_table` / matcher: when `e` is a pool, treat a
     leading `:any` / `:all` symbol as mode, not payload.
   - Store mode in the pattern table `T` (e.g. `T.mode`).
   - Invalid symbol -> `assert` with clear message.
   - Default mode `:any` when absent.

2. **Empty-pool short-circuit**
   - At await entry (near check_task_ret:673), if `e` is a pool
     and `#ts == 0`, return `nil, nil, ts` without yielding.

3. **`:any` return reshape** (`run.lua:567-569`)
   - Return `ret, t, ts` instead of `t, ts`.
   - `ret` = the terminated task's `t.ret`.

4. **`:all` native loop**
   - On each pooled-task death match, if `#ts > 0` keep waiting
     (re-yield, suppressing the wakeup).
   - When the death that drains the pool occurs (`#ts == 0`),
     return that task's `ret, t, ts`.

5. **Docs** — update `api.md:269` to document mode arg + ret shape.

6. **Migrate call sites** — grep `await(` over pool vars across
   `atmos/`, `tst/`, examples; update `t,ts = await(ts)` to the
   new `ret,t,ts` shape.

## Open / to confirm

- Invalid 2nd arg: assert (assumed). Confirm message wording.
- Symbol spelling: `:any` / `:all` (confirm vs `:one`/`:all`).

## Progress

- [x] Semantics decided (decisions table above)
- [x] Step 1: parse mode arg (await_to_table, T.mode, default :any, assert)
- [ ] Step 2: empty-pool short-circuit
- [ ] Step 3: :any return reshape
- [ ] Step 4: :all native loop
- [ ] Step 5: api.md docs
- [ ] Step 6: migrate call sites
