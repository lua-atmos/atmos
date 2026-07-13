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

## Follow-up: empty pool double-wake

After the consume fix, a loop-consumer gets a spurious `nil` wake
each time the pool drains.

`:any` has two independent wake conditions; on the last termination
they fire back-to-back:

| wake | state                           | branch    | returns |
| ---- | ------------------------------- | --------- | ------- |
| 1    | `ts.ret` set, task not gc'd yet | `:584`    | `char`  |
| 2    | task gc'd, `#ts==0`, ret nil    | `:582`    | `nil`   |

```
run.lua:581   elseif awt.mode == 'any' then
run.lua:582       if #ts == 0 then          ;; immediate if empty -> nil
run.lua:583           return nil, nil, ts
run.lua:584       elseif ts.ret then        ;; real termination   -> char
```

The consumer cannot distinguish "pool empty" from "a task ended".
Not caused by the consume fix; only unmasked by it (the old latch
never let the loop reach the empty path).

### Decision: empty never wakes; `ts.ret` overwrite; unified branch

The `awt.awoke` / immediate-`#ts==0`-return line of attempts is
rejected.
It could not survive the two facts below, so the design was reduced
to a single rule: **a tasks await wakes only on a real termination
(`ts.ret`); an empty pool blocks.**

Why the empty-wake variants failed:

- Flag on `awt` does not persist (the language rebuilds the await
  literal each iteration), and even when it did (`loop_on` reuses
  the table) it still shadowed already-terminated results.
- Checking `#ts==0` before `ts.ret` returned a spurious `nil` on any
  emit that resumed the consumer after the pool drained (the real
  non-empty -> empty bug), and shadowed tasks that terminated before
  the consumer's first await.

Final semantics:

| mode   | wakes on         | returns                  | empty pool |
| ------ | ---------------- | ------------------------ | ---------- |
| `:any` | each termination | that task `(ret,t,ts)`   | blocks     |
| `:all` | pool empty       | last terminator `(ret,t,ts)` | blocks |

Two coordinated edits:

- `run.lua:132` — latch -> overwrite: `t._.up.ret = t` (was
  `... or t`). `ts.ret` now holds the most-recent terminator.
- `run.lua:577` — one trigger/return, mode picks the condition:
  `:any` fires on `ts.ret`; `:all` fires on `ts.ret and #ts==0`
  (never consumes on intermediate deaths, so it reads the last).
  Both return `(t.ret, t, ts)`; invalid mode asserts.

Side effect (accepted, WON'T DO): the overwrite also flips `:any`
simultaneous-termination surfacing from first -> last. Per-emit
nested wakes make it rarely observable.

Empty `:all` no longer returns `ts` vacuously; "wait for all" on an
empty pool blocks. The vacuous "all done" is expressed at the call
site: `while #ts > 0 do await(:any ts) end`.

## Verification

- Maintainer runs `tst/tasks.lua`:
    - `:any` returns/consumes per termination; loop blocks between.
    - `:all` wakes on drain, returns the last terminator.
    - empty `:any` and `:all` both block.
    - bad mode asserts "invalid await : invalid mode".

## Progress

- [x] Root cause identified (`run.lua:132`, `:584`).
- [x] Failing test added ("pools :any loop consumes one-by-one").
- [x] Consume fix (`ts.ret = nil` on `:any` return).
- [x] Simultaneous-termination: WON'T DO.
- [x] Empty-pool double-wake investigated: `awt.awoke` / awoke /
      `ts.first` / pool-`emptied` approaches all REJECTED (do not
      persist and/or shadow results).
- [x] Real bug: non-empty -> empty spurious `nil` on any resuming
      emit (not the plain-drain path).
- [x] Final fix: overwrite latch (`run.lua:132`) + unified tasks
      branch (`run.lua:577`); empty blocks; `:all` returns the last
      terminator.
- [x] Tests updated (`tst/tasks.lua`): drain -> no `nil`; drain then
      emit -> no `nil`; loop on empty -> blocks; `:all` -> last
      terminator; empty `:all` -> blocks; bad mode asserts.
- [x] Maintainer verification: all tests pass.
