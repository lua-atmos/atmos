# Runtime gate: surface `xtask(rawfunc)` must fail

## DONE (@ 2026-06-20)

- [x] Fix 1 applied: `run.lua:406` `or T` -> `or (tra and T)`.
- [x] Fix 2 applied: `run.lua:407` `assertn(3,...)` -> `assertn(2,...)`
      (caller attribution -- blames the user call line, error level 3).
- [x] Test (semantics): `tst/proto.lua` err 5 (`xtask(rawfn)` -> throws).
- [x] Test (trace): `tst/errors.lua` two gate-trace blocks --
      `spawn(rawfn)` + `xtask(rawfn)` assert `/tmp/err.lua:N: invalid
      ... : expected task prototype` (caller-attributed, not run.lua).
- [x] Suite GREEN (`cd tst && lua5.4 all.lua`); both trace tests pass,
      no regressions.
- [x] Committed + pushed `v0.7` (1d5cdd8 `error : xtask(f)`).
- [x] Downstream atmos-lang (`/x/atmos-lang` `260620-task.md` §4):
      "is 3b" uncommented + active (exact full-trace assert); temp
      `print(out)` removed. DONE (tracked in that repo's plan).

## FOLLOW-UP (@ 2026-06-22) -- re-spawn guard (grew out of this gate)

Question raised: spawning an ALREADY-spawned instance. A prototype is
reusable (`spawn(T)` mints a new instance each call); an `xtask`
instance is single-owner. Re-spawning the same instance hit a BARE
`assert(t._.up==nil and up)` (msg `assertion failed!`), inconsistent
with the surrounding `assertn(2,...)` gates.

- [x] `run.lua` `M.spawn`: bare assert -> `assertn(2, t._.up==nil,
      "invalid spawn : unexpected active task")`, checked BEFORE tree
      mutation; trailing `t._.up = assert(...)` tidied to `t._.up = up`.
- [x] Test (semantics): `tst/proto.lua` err 6 (re-spawn -> throws).
- [x] Test (trace): `tst/errors.lua` re-spawn block, caller-attributed.
- [x] Suite GREEN; committed + pushed `v0.7`
      (9a2c917 `fix : check active task spawn` + 743be3c tidy).

ALL DONE -- no pendings in this plan.

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

## Fix 2 -- error attribution (`assertn(3)` -> `assertn(2)`)

After Fix 1, `xtask(\{})` THROWS but the error blames `run.lua:407`
instead of the user's call site. `M.spawn` reports `anon.atm:N`
correctly because it uses `assertn(2, ...)`; `M.xtask` uses level 3.
Level 3 was tuned for the INTERNAL `M.spawn -> M.xtask` path (one frame
deeper), but M.spawn already guards types before calling M.xtask
(`run.lua:448` `type(t)=='function'`, `:453` `meta_task`), so this
assert now fires ONLY on the SURFACE path -- where level 3 over-counts.

`atmos/run.lua:407`:

    - assertn(3, type(f)=='function', "invalid xtask : expected task prototype")
    + assertn(2, type(f)=='function', "invalid xtask : expected task prototype")

Verify: `xtask(\{})` error's `(throw)` line reads `[string "anon.atm"]:1`
(matching `spawn (nil)()`), not `run.lua:407`. This is what unblocks the
atmos-lang "is 3b" exact-match assert.

## Verify

- runtime: `xtask(\{})` (surface) throws `invalid xtask : expected task
  prototype` AT the caller's source line; `xtask(T)`, `xtask()`, and
  inline `spawn {}` all still work.
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
