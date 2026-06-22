# Plan: `await(f, ...)` spawn sugar

## Status

DONE. All tests pass.

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
- FLAGGED (still open, separate): a non-task callable falls to
  `run.await` and reports "invalid await : invalid event pattern"
  rather than spawn's "invalid spawn : expected task prototype".

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
