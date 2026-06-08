# Plan: Clock await patterns as plain numbers (microseconds)

## Idea

Allow `await(<number>)` where the number is a **clock duration in
microseconds**, instead of requiring a clock table (`clock{...}` / `@..`).

```
await(1000000)      ;; wait 1s  (1_000_000 us)
```

## Current state (lua-atmos/atmos runtime)

| file                       | place                  | now                                  |
|----------------------------|------------------------|--------------------------------------|
| atmos/run.lua              | `clock_to_ms` (l.75)   | clock table -> **milliseconds**      |
| atmos/run.lua              | `meta_clock` (l.82)    | countdown via `a.cur`, emits `'clock'`|
| atmos/run.lua              | `await_to_table` (l.628)| `meta_clock` table -> countdown patt |
| atmos/run.lua              | bare number (l.643)    | falls to `'=='` -> matches `emit(n)` |
| atmos/env/clock/init.lua   | `step` (l.12)          | `emit('clock', dt_ms, now)` in **ms**|

Clock match works via the `__atmos` metamethod path on `meta_clock`.
The emit carries `dt` (elapsed) + `now`.

## Core conflict

`await(<number>)` today means "match an emit equal to this number".
Making a bare number a clock duration is a **breaking semantic change**:
bare-number event matching would have to go through payloads
(`await(:tag, n)`) instead.

## Open decisions

1. Unit: idea says **microseconds**, but `clock_to_ms` + clock env use
   **milliseconds**. Options:
   a. switch whole clock subsystem to microseconds (env emits us, rename
      `clock_to_ms` -> `clock_to_us`)
   b. keep ms internally, treat the number arg as us and convert at the
      boundary
2. Keep clock tables (`@..` literals / `clock{}`) too, or replace by numbers?
3. Does `await(<number>)` matching a literal `emit(<number>)` need to stay
   supported anywhere? (audit tst/ + exs/)

## Implementation surface (sketch)

- `await_to_table`: add `type(e)=='number'` branch -> build a clock countdown
  pattern (carry `cur` = duration), reusing meta_clock countdown logic.
- Countdown state for a number: wrap in a small clock-like table, or a new
  numeric pattern tag handled in `check_ret`.
- `atmos/env/clock/init.lua`: emit duration in chosen unit.
- `api.md`: update `await` `c: clock` row to document the number form.
- `manual.md`: doc `@..` <-> number relation -- OUTSIDE worktree, cannot edit.

## Status

- [x] Located clock await impl (run.lua + clock env)
- [x] Identified bare-number `'=='` conflict
- [ ] Resolve open decisions (unit, keep tables?, matching audit)
- [ ] Implement number branch in `await_to_table` / `check_ret`
- [ ] Adjust clock env unit
- [ ] Update api.md
