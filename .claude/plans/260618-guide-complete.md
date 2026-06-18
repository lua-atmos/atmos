# Plan: complete guide.lua coverage

## Status

PENDING -- deferred. guide.lua now mirrors guide.md section numbering
1:1 (see `260616-task-xtask.md`), so the coverage gaps are explicit.

## Context

`tst/guide.lua` is the runnable mirror of `guide.md`; each code example
carries a `<!-- tst/guide.lua : N.M -->` provenance marker.
After the renumber, guide.lua covers sections 1-5 and 7.1; two gaps
remain with NO runnable counterpart:

| guide.md       | gap reason                                            |
|----------------|------------------------------------------------------|
| §6 Errors      | catch/throw -- not yet in guide.lua                  |
| §6.1 trace     | bidimensional stack trace -- uncaught by design      |
| §7.1 `while`   | pseudo-code analogy (`map`/`filter` undefined)       |
| §7.2 thread    | `thread` + heavy CPU + 20s + nondeterministic        |

## Candidates

| add to guide.lua | feasibility                                       |
|------------------|---------------------------------------------------|
| §6 catch/throw   | EASY -- clean, deterministic output `false  Y`.   |
|                  | Fills the §6 gap as a new `6.1` block.            |
| §6.1 trace       | HARD -- the example's value IS the uncaught trace.|
|                  | Wrapping in `catch` to pass hides what it shows.  |
|                  | Options: skip, or add a guarded propagation-only  |
|                  | check (no trace assertion).                       |
| §7.1 `while`     | SKIP -- illustrative pseudo-code, not runnable.   |
| §7.2 thread      | MEDIUM -- scale to small `cpu()` + short timeout; |
|                  | print only a deterministic field (worker race     |
|                  | stays nondeterministic, so assert on value/count).|

## Recommendation

1. Add §6 catch/throw as guide.lua `6.1` (closes the §6 gap; markers in
   guide.md §6 then point to `6.1`).
2. Skip §7.1 `while` pseudo-code (leave unmarked).
3. Decide §7.2 thread separately: scaled-down `7.2` block, or leave
   uncovered and note it explicitly.
4. §6.1 trace: lean SKIP (keep it doc-only); revisit if a stable way to
   assert the trace appears.

## Open questions

- thread: add a scaled deterministic `7.2`, or leave uncovered?
- trace: skip, or guarded propagation-only check?

## Cross-refs

- `260616-task-xtask.md` -- numbering / markers / do_spawn pass.
- guide.md / tst/guide.lua -- current covered sections 1-5, 7.1.
