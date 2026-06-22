# Plan: `await(f, ...)` spawn sugar

## Status

PENDING

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
