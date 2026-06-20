# Runtime gate: surface `xtask(rawfunc)` must fail

## DONE (@ 2026-06-20)

- [x] Fix applied: `run.lua:406` `or T` -> `or (tra and T)`.
- [x] Test added: `tst/proto.lua` err 5 (`xtask(rawfn)` -> throws).
- [x] Suite GREEN (`cd tst && lua5.4 all.lua`); no regressions.
- [ ] Downstream atmos-lang (`/x/atmos-lang` `260620-task.md` §4):
      uncomment "is 3b" negative test; drop temp `print(out)`. NOT done.
- NOT committed/pushed (per workflow -- ASK first).

## Goal

`xtask` is the instance constructor. From a PROTOTYPE (`xtask(T)`) or
zero-arg "me" (`xtask()`) it is valid. But a SURFACE call on a raw Lua
function -- `xtask(\{})` / `xtask(somefn)` -- should be REJECTED with
`invalid xtask : expected task prototype`. Today it SUCCEEDS.

## Why it currently succeeds

`atmos/run.lua:406` (inside `M.xtask`):

    local f = (getmetatable(T)==meta_task and T._.f) or T

The `or T` fallback accepts ANY function. That fallback exists only for
the INTERNAL transparent-spawn path, where `M.spawn` calls
`M.xtask(dbg, tra=true, rawfn)` for inline `spawn { ... }` bodies. For
the surface accessor (`init.lua` `function xtask(T)` -> `run.xtask(dbg,
false, T)`), `tra` is FALSE, yet `or T` still lets a raw function through.

## Fix (one line)

`atmos/run.lua:406`:

    - local f = (getmetatable(T)==meta_task and T._.f) or T
    + local f = (getmetatable(T)==meta_task and T._.f) or (tra and T)

Behavior after:
- prototype, any `tra`          -> `T._.f` (works, unchanged)
- raw fn, `tra=true` (internal) -> `(true and T)` = `T` (works, unchanged)
- raw fn, `tra=false` (surface) -> `(false and T)` = `false`
  -> `assertn(type(f)=='function', "invalid xtask : expected task
     prototype")` THROWS.

## Verify

- runtime: `xtask(\{})` (surface) throws `invalid xtask : expected task
  prototype`; `xtask(T)`, `xtask()`, and inline `spawn {}` all still work.
- run the lua-atmos suite (no regressions in spawn/await/transparent-task
  tests).

## Downstream (atmos-lang, separate repo `/x/atmos-lang/atmos`)

Tracked in `atmos-lang .claude/plans/260620-task.md` §4. Once this gate
lands, in `tst/x.lua`:
- the "is 3b" negative test (`xtask(\{})` -> ERROR) goes GREEN
  (it was kept commented / RED pending this gate);
- remove the temporary `print(out)` debug line.

## Note

Symmetric with the atmos-lang surface model: `task(f)` cannot bless a
raw function into a prototype (`task` is a keyword), and after this gate
`xtask(f)` cannot make an instance from a raw function either -- so
task-ness is always DECLARED, never retrofitted onto a plain `func`.
