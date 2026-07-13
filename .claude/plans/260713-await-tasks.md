# await(:any ts) — sticky pool result

## Problem

A single `await(:any ts)` works as documented.
Looping over it to consume terminations one-by-one does not:

```
loop v on :any ts {
    ...    ;; fires forever with the same first-terminated task
}
```

Once any task in the pool terminates, the await keeps returning that
same task immediately, so the loop spins instead of blocking for the
next termination.

## Root Cause

The pool field `ts.ret` is a sticky latch: set on first termination,
never cleared.

| step               | location        | effect                                  |
| ------------------ | --------------- | --------------------------------------- |
| pool task ends     | `run.lua:132`   | `ts.ret = ts.ret or t` (latch first)    |
| `await(:any ts)`   | `run.lua:584`   | `elseif ts.ret then return ...`         |
| loop re-awaits     | `run.lua:581`   | `ts.ret` still set, returns immediately |

```
run.lua:581   elseif awt.mode == 'any' then
run.lua:582       if #ts == 0 then
run.lua:583           return nil, nil, ts
run.lua:584       elseif ts.ret then
run.lua:585           return ts.ret.ret, ts.ret, ts
```

Every `.ret` write in `run.lua`: set at `:127` / `:132`, init `nil`
at `:425`.
Nothing ever resets the pool `ts.ret`.
The `or` at `:132` also prevents it from ever advancing to a later
terminated task.

## Fix

Consume `ts.ret` when the `any` branch returns it.

```
run.lua:584   elseif ts.ret then
                  local t = ts.ret
                  ts.ret = nil        ;; consume; next await blocks again
                  return t.ret, t, ts
```

The dead task is already dropped from `ts._.dns` by `task_gc`, so
after clearing, the next iteration blocks until another task ends.

## Open Questions

- Simultaneous terminations: WON'T DO.
    - `ts.ret` holds only one task (`or` at `:132`).
    - If two end in the same reaction, the second is lost.
    - Decision: keep the single latch; `:any` surfaces only the
      first of tasks ending in the same reaction.
- Confirm no existing single-shot `await(:any ts)` user relies on
  the latch persisting after the await returns: OK, all tests pass.

## Verification

- Ask maintainer to run:
    - single `await(:any ts)` still returns the terminated task.
    - `loop v on :any ts` blocks between terminations (no spin).
    - `await(:all ts)` unaffected.

## Progress

- [x] Root cause identified (`run.lua:132`, `:584`).
- [x] Failing test added (`tst/tasks.lua`, "pools :any loop
      consumes one-by-one"): expects `1\n2\n`, latch gives `1\n1\n`.
- [x] Apply consume fix (`run.lua:584`: read `ts.ret` into local,
      set `ts.ret = nil`, return the local).
- [x] Decide on simultaneous-termination handling: WON'T DO
      (single latch kept; first-of-reaction only).
- [x] Maintainer verification: all tests pass.
