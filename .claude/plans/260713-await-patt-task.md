# await-patt-task : task prototype as first-class await pattern

Runtime half of the Atmos compiler plan :
`/x/atmos-lang/atmos/.claude/plans/260713-await-patt-task.md`

## Goal

`M.await` accepts a `{tag='spawn', T, args...}` **carrier** : it spawns
`T` inside the awaiting task/branch and awaits the resulting xtask.
**Carrier-only** (decision) : the compiler always emits the carrier,
even for no args ; a bare prototype is NOT an await pattern, so `M.await`
needs a single branch (mirrors the `S.is` stream case).
Then `init.lua`'s `await` sugar collapses and the compiler needs no
thunk lowering :

```
await T(a,b)                ;; -> {tag='spawn', T, a, b} : solo
await T() || :X             ;; -> {tag='spawn', T} sub, aborted on lose
watching T()                ;; free : funnels into M.await
loop on T()                 ;; free : funnels into M.await
```

## Why runtime-first works

- `or`/`and` subs recurse `M.await` inside **transparent branch tasks**
  (`run.lua:508-509`, `par_any` spawns each sub with `tra=true`,
  `run.lua:889`)
- inside a branch, `M.me(true)` is the branch task itself, so
  `M.spawn(dbg, nil, ...)` parents the new `T` to the branch
- when another branch wins, `meta_par.__close` cascades and aborts `T`
  via `meta_xtask.__close` (`run.lua:57-71`, `859-865`)
- mirrors the existing stream case : `S.is` spawns a wrapper task
  inside `M.await` (`run.lua:553-554`)

## Changes

| file       | place              | change                              |
|------------|--------------------|-------------------------------------|
| `run.lua`  | `M.await` `~553`   | new branch `tag=='spawn'` -> spawn `awt[1]` with `awt[2..]` args, recurse |
| `init.lua` | `await` `72-83`    | collapse to `run.await(run.TIME, ...)` |

Carrier-only : no `meta_task` branch, and the `489-492` varargs assert
stays as-is (the carrier packs args in the table, so `M.await` still
receives a single operand).

Sketch (next to the `S.is` branch in the pre-loop dispatch chain) :

```lua
elseif tag == 'spawn' then
    return M.await(time, M.spawn(debug.getinfo(2), nil, false, awt[1], table.unpack(awt, 2, #awt)))
```

## Notes

- bare prototype dropped : compiler always emits the carrier, so
  `M.await` never sees a raw `meta_task` operand (no `X.is` / no
  `meta_task` local check needed in `run.lua`)
- error message : `run.lua:500` already rejects plain functions
  ("invalid await : unexpected function"); collapsing `init.lua` drops
  its friendlier "invalid spawn : expected task prototype" -> update
  reject-fn tests (`await.lua` `reject fn 1`, `reject fn 4`) to the
  `M.await` message, or keep a thin function check in the sugar
- `{tag='spawn'}` carrier + nil args : `#awt` is unreliable with nil
  holes; consider storing `n` (compiler emits `table.pack`-style) or
  document no-nil-args
- `debug.getinfo` frame shifts from the user call site into `M.await`
  (cosmetic : error location only)
- `:any [T(a), U(b)]` pool form is compiler-side (maps to `or`/pool
  tables); no extra runtime support beyond the two branches above
- `until`/`while`/`not` re-await `awt[1]` per rejected event
  (`run.lua:517-551`) : with a prototype/carrier operand this RESPAWNS
  `T` each round — explicit semantics decision deferred to the
  compiler plan (STEP 4)

## Tests

Failing tests appended to `tst/await.lua` (`--- AWAIT / TASK PROTOTYPE ---`) :

| test                       | form                                          |
|----------------------------|-----------------------------------------------|
| proto 1 : carrier solo     | `await {tag='spawn', T}`                       |
| proto 2 : carrier args     | `await {tag='spawn', T, 3, 4}`                |
| proto 3 : in or, T wins    | `await {tag='or', {tag='spawn',T,'hi'}, 'Y'}` (single ret) |
| proto 4 : in or, aborted   | `await {tag='or', {tag='spawn',T}, 'X'}`      |
| proto 5 : in and           | `await {tag='and', {tag='spawn',T,5}, 'X'}`   |
| proto 6 : watching         | `watching({tag='spawn',T,'done'}, body)`      |
| proto 7 : loop_on respawn  | `loop_on({tag='spawn',T,'tick'}, body)`       |

All carriers (no bare prototype) per the carrier-only decision.
Proto 3/5/6/7 pass args through the carrier and verify they reach the
spawn ; proto 4 has no arg (loser is aborted before it can observe one).

Appended (not inserted) : keeps `await.lua:297` / `await.lua:372`
hardcoded line-number asserts valid.

## Status

- [x] `{tag='spawn', T, args...}` branch in `M.await` (`run.lua` after `S.is`)
- [x] collapse `init.lua` `await` sugar : bare `await(T,...)` now wraps into
      the carrier -> single `M.await` path (kept the `function` guard, so
      `task.lua:308` and `reject fn 1/4` are unaffected)
- [~] reconcile reject-fn error message : NOT needed (guard kept in sugar)
- [x] confirm in-branch lifetime (`await T() || :X` aborts loser) : proto 4
      passes (loser's `defer` runs on abort)

## Done

Runtime half complete : all proto 1-7 tests pass + no regressions.
Compiler half (carrier emission for `T(a,b)` / `:any [T(a), U(b)]`) is
tracked in `/x/atmos-lang/atmos/.claude/plans/260713-await-patt-task.md`.
Ready to move to `./.claude/plans/done/`.
