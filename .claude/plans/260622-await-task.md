# Plan: `await(f, ...)` spawn sugar

## Status

DONE. All tests pass.

Includes the `until`/`while` synchronous-predicate work (added
2026-06-22 after bare `await(f)` became an error) plus the earlier
spawn sugar, dbg-location fix, and func/task gate.

### Addendum: debug-location bug + fix

The first sugar landed as `await(spawn(awt, ...))`. The `spawn`
wrapper (init.lua) captures `debug.getinfo(2)`, so the spawned
task's `_.dbg` pointed at init.lua (the sugar line), and every
runtime traceback blamed init.lua instead of the user's `await`
call site.

Fix (APPLIED, init.lua:75): spawn via `run.spawn` directly,
capturing the user frame:

    return await(run.spawn(debug.getinfo(2), nil, false, awt, ...))

`debug.getinfo(2)` inside `await` = await's caller = user site.

- test: `tst/errors.lua` "await sugar: task dbg location" --
  exec-style traceback test; asserts the `(task)` frame is
  `/tmp/err.lua:3`, not init.lua. PASSES (with the fix); the full
  trace `:2 (loop) / :4 (throw) <- :3 (task) <- :2 (task)` is
  confirmed.
- func/task error msg (FIXED): `await(rawfn, ...)` used to fall to
  `run.await` and report "invalid await : invalid event pattern".
  The sugar now raises "invalid spawn : expected task prototype"
  (via `assertn(2,...)`, blaming the user site) for ANY raw
  function (`type(awt)=='function'`; the `select('#')>0` guard was
  dropped). NOTE: this also blocks bare `await(f)` as a predicate --
  which is why the synchronous predicate moves to
  `{tag='until'/'while', f}` (see below). Streams (tables) and
  `await(1,2)` untouched. Test: `tst/task.lua` "await 3".

Design refinement: the sugar keys off a **task prototype**, not a
raw function. `X.is(awt, 'task')` -> spawn it. This leaves the
function slot (condition predicate) untouched: no repurposing, no
conflict, no need to remove the run.lua:597 branch.

- [x] step 1: sugar in `atmos/init.lua` `await` wrapper --
      `if X.is(awt,'task') then return await(spawn(awt, ...)) end`.
      Added `local X = require "atmos.x"` (cached; run.lua already
      loads it).
- [x] step 2: api.md await table -- added Tasks-group row
      `T: task` -> `T` ends -> `v,t`; note `await(T, ...)`.
- [x] step 3: api.md `S.on` "exception" note -- LEFT as-is.
      `S.on(f)` still spawns a *raw function* via streams' own
      `fr_spawn`, which diverges from `await(f)` = predicate. The
      note stays accurate until streams aligns (separate plan).
- [x] test: `tst/task.lua` "await 9: task prototype - spawn sugar"
      -- `await(task(f), 10)` spawns with args, awaits result `20`.
- [n] args doc note on the `T: task` row -- WON'T DO (user).
- [>] streams alignment (`S.on` keys on prototype, tests ->
      `S.on(task(T))`) -- NOT this plan; separate.

## Consequences / follow-ups

- run.lua:597 function-predicate branch: KEEP (untouched slot).
- `await(1,2)` error test still passes (number is not a `task`).
- Caveat: `loop_on`/`watching` call `run.await` directly
  (run.lua:844,911), bypassing the wrapper -- they do NOT get the
  prototype sugar. Out of scope; note only.
- Streams alignment (separate): for `S.on(T)` to forward to
  `await`, `S.on` should also key on a `task` prototype, and tests
  move from `S.on(T)` (raw fn) to `S.on(task(T))`. Tracked as the
  optional cleanup below.

## Optional (later)

- collapse `streams.lua` `fr_spawn` into pure `await`-forwarding,
  keying on a `task` prototype (mirrors the runtime sugar).

## Context

Split off from `260622-stream-on`.

The streams source `S.on(f, ...)` spawns `f` as a task each pull and
streams its results. But the runtime `await` rejects this form:

| call            | today                          |
|-----------------|--------------------------------|
| `S.on(f, ...)`  | works (stream sugar `fr_spawn`)|
| `await(f, ...)` | error (extra args rejected)    |

So `S.on` carries a spawn convenience that `await` itself cannot
express -- an inconsistency.

## Key fact: the function slot is free

Bare `await(f)` as a *condition predicate* is retired. Predicates
now go through `{tag='until'/'while', pat, fn}`. Verified:

- 0 test uses of `await(<bare function>)`.
- toggle `filter` (run.lua:773) is always an event pattern
  (`'Draw'`, `{tag='not','Tick'}`), never a function.
- the function-predicate branch at `run.lua:597-601` is therefore
  vestigial / unreachable from public + internal call sites.

So the function argument of `await` can be repurposed to mean
"spawn this as a task", with no ambiguity.

## Fix

Define, in the runtime:

    await(f, ...)  ->  spawn(task(f), ...) ; await(instance)

This mirrors the existing stream branch (`run.lua:552-553`, `S.is`),
which already spawns + awaits. Handle it at the top of `await`,
before the no-extra-args assertion, so `...` is allowed only for a
function `awt`.

### Why this is the right shape

- `S.on(x)` = `loop { yield await(x) }` forwards every form,
  including the spawn case -- no special-casing needed.
- Re-run preserved: each pull calls `await(f,...)`, spawning a
  *fresh* task -> `XY, XY, ...`.
- No `fr_function`, no closures; existing tests unchanged
  (`S.on(T,'A')` keeps working via `await(T,'A')`).
- `await(1,2)` error test still passes: a non-function `awt` with
  extra args is still rejected.

## Steps

1. atmos/run.lua: at await head (~490), handle
   `type(awt)=='function'` -> spawn `task(awt)` with `...`, await
   the instance; place before the assertion so args pass only for
   functions.
2. atmos/run.lua: remove the now-unreachable function-predicate
   branch (597-601).
3. api.md: add a Tasks-group row to the await table --
   `f: function` -> `f` ends -> `v,t` (form `await(f, ...)`).
4. api.md: drop the "exception" framing on the `S.on` source note;
   `S.on(f,...)` is now plain `await`, not a quirk.

## Verify before editing

- exact `M.spawn(...)` arg signature (mirror `run.lua:553`) so
  `...` forwards into the spawned body correctly.

## Optional (later)

- collapse `streams.lua` `fr_spawn` into pure `await`-forwarding,
  since `await` now covers the spawn case.
  (DONE in `done/260622-stream-on.md`.)

## until/while synchronous predicate (PENDING)

### Problem

Bare `await(f)` evaluated its predicate SYNCHRONOUSLY: `f(nil)` runs
before the first `coroutine.yield()` (run.lua:597 is checked at the
top of the loop, yield is at 605), so it can return without waiting
for any event. Now that bare `await(f)` errors, that capability has
no public form.

`until`/`while` cannot replace it: they always `M.await(time,
awt[1])` first (run.lua:534) -- yielding on a base pattern before
any predicate is tested. No base pattern yields immediately (e.g.
`{tag='until', 0, f}` would busy-loop).

### Decision

Give `until`/`while` a function-first-arg mode == old synchronous
`await(f)`:

    await{tag='until', f}  ===  await(f)   (old, synchronous)

- discriminator: `awt[1]` is a function -> predicate mode (no base
  await; check now + on each event). Else -> current base-pattern
  mode.
- relax `#awt >= 2` to allow `{tag='until', f}` (single function).
- `until`: accept when predicate holds (== run.lua:597 semantics).
- `while`: mirror -- accept when predicate FAILS (synchronous).
- run.lua:597 stays as the shared engine (reached via `until` now,
  and still via `loop_on(f)`/`watching(f)`); bare public `await(f)`
  stays gated/erroring.

### Steps

0. [x] REMOVE bare-function support first (option a):
   - run.lua: deleted the `elseif type(awt)=='function'` predicate
     branch (was ~597). A bare function now has no engine.
   - api.md: removed the standalone `f: function` Condition row.
   - init.lua gate KEPT: public `await(f)` still errors cleanly.
   - migrated the bare-function pattern sites to `{tag='until', f}`:
     `tst/task.lua:403` "loop_on 2" (`loop_on(function...)`) and
     `tst/par.lua:353` "watching 6" (`watching (function...)`). The
     latter was missed at first (grep skipped the space in
     `watching (`) -> surfaced as the "watching 6" failure; both
     `loop_on`/`watching` route a bare-function pattern to
     `run.await`, which no longer has the function branch.
   - NOTE: suite will NOT pass until step 1 lands (the migrated
     site + any `{tag='until', f}` hit `#awt>=2` and error). Do not
     run tests between step 0 and step 1.
1. [x] run.lua `until`/`while` (final shape):
   - function first-arg -> assign `awt` and fall through to the
     re-added bare-function branch (~594):
         local f = awt[1]
         awt = f
         if tag == 'while' then
             awt = function (e) return not f(e) end
         end
     `f` stays immutable so the `while` closure closes over the real
     predicate (NOT the reassigned var -> no infinite recursion);
     594's truthy-accept + `(ret~=true and ret) or emt` returns the
     event for `while`. (Two bugs caught in review: missing
     `awt = f` -> hang; `f = function() not f() end` self-capture ->
     recursion.)
   - base form: EXACTLY one predicate --
     `assertn(#awt==2 and type(awt[2])=='function', "... expected
     single function predicate")`; loop does `res = awt[2](it)`,
     `until` returns `(res~=true and res) or it`, `while` returns
     `it`. The `(res~=true and res) or it` matches api.md ("defaults
     to e if true") AND the function-form (594) -- so a predicate
     returning bare `true` yields the EVENT in both forms. (Surfaced
     by "until 9", whose boolean predicate made `out(v[1])` index a
     `true`.)
   - review bugs fixed along the way: swapped `preds` return,
     undefined `it`, post-yield table guard (earlier iteration);
     `while` was acting like `until` (negation fix above).
2. [x] api.md: added a note under the await table -- a `function`
   first item makes `until`/`while` a synchronous predicate (no base
   pattern); the `f: function` row was already removed.
3. [x] tst/await.lua:
   - appended at EOF: "until fn 1" (synchronous, no event),
     "until fn 2" (re-checked per event), "while fn 3" (mirror).
   - single-predicate refactor: rewrote "until 3/4/7" from two
     predicates to one (predicate now returns the VALUE, `out(v)`),
     and "until 8" error -> "expected single function predicate".
   - fixed the hardcoded line refs shifted by the -3 lines:
     `await.lua:300->297` (until 8) and `375->372` (bare pool).
   Also migrated `tst/task.lua:403` "loop_on 2" + `tst/par.lua:353`
   "watching 6" in step 0.

### Verify

- `await{tag='until', f}` == old `await(f)` (synchronous first
  check, then re-check per event).
- `while` negation correct.
