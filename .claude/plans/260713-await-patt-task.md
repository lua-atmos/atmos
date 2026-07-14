# await-patt-task : task prototype as first-class await pattern

Runtime half of the Atmos compiler plan :
`/x/atmos-lang/atmos/.claude/plans/260713-await-patt-task.md`

## Goal

`M.await` accepts a task **prototype** directly (spawn inside the
awaiting task/branch), plus a `{tag='spawn', T, args...}` carrier for
prototype calls with args.
Then `init.lua`'s `await` sugar collapses and the compiler needs no
thunk lowering :

```
await T(a,b)                ;; solo : varargs reach spawn directly
await T() || :X             ;; sub spawned in-branch, aborted on lose
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
| `run.lua`  | `M.await` `489-492`| relax `select('#',...)==0` assert : varargs allowed when `awt` is a prototype |
| `run.lua`  | `M.await` `~553`   | new branch `getmetatable(awt)==meta_task` -> `M.await(time, M.spawn(dbg, nil, false, awt, ...))` |
| `run.lua`  | `M.await` `~553`   | new branch `tag=='spawn'` -> spawn `awt[1]` with `awt[2..]` args, recurse |
| `init.lua` | `await` `72-83`    | collapse to `run.await(run.TIME, ...)` |

Sketch (next to the `S.is` branch in the pre-loop dispatch chain) :

```lua
elseif getmetatable(awt) == meta_task then
    return M.await(time, M.spawn(debug.getinfo(2), nil, false, awt, ...))
elseif tag == 'spawn' then
    return M.await(time, M.spawn(debug.getinfo(2), nil, false, awt[1], table.unpack(awt, 2, #awt)))
```

## Notes

- `meta_task` is local to `run.lua`, so the check lives there (no
  `X.is` needed)
- error message : `run.lua:500` already rejects plain functions
  ("invalid await : unexpected function"); `init.lua`'s friendlier
  "invalid spawn : expected task prototype" is lost unless kept as a
  thin check in the collapsed sugar
- `{tag='spawn'}` carrier + nil args : `#awt` is unreliable with nil
  holes; consider storing `n` (compiler emits `table.pack`-style) or
  document no-nil-args
- `debug.getinfo` frame shifts from the user call site into `M.await`
  (cosmetic : error location only)
- `:any [T(a), U(b)]` pool form is compiler-side (maps to `or`/pool
  tables); no extra runtime support beyond the two branches above

## Status

- [ ] relax varargs assert for prototype case
- [ ] `meta_task` branch in `M.await`
- [ ] `{tag='spawn', T, args...}` branch in `M.await`
- [ ] collapse `init.lua` `await` sugar
- [ ] confirm in-branch lifetime (`await T() || :X` aborts loser)
