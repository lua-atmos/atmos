# clock / and / or / not — derive from loop / await / par

## Scope

Drop stateful await primitives.
Express them with three mechanisms that already exist:

- per-emit logic (`==`, `or`, `not`, single-event `and`)
  -> `{ it ... }` func predicate
- duration / accumulation (clock, count, sequence)
  -> `loop { await('clock') }`
- temporal / over task bodies (X-then-Y, race, join)
  -> `par_and` / `par_or`

Runtime shrinks: remove `__atmos`, `meta_clock`, `M.clock`, `clock_to_ms`,
and the `M.await` combinator dispatch.
Supersedes the passive-table and `__atmos`-object approaches.

## Why

- `or` / `not` / single-event `and` are stateless
  -> a func predicate over `it` (already the `'func'` path in `check_ret`).
- clock / and-across-emits are stateful, but the state is just a local in a
  loop -> `loop { await('clock') }`.
  No pattern-table state, no reset rule, no shared-object footgun.
- temporal `and` / `or` already exist as `par_and` / `par_or`.
- => no stateful primitive is needed; the core is loop + await + par + func.

## Design (all mechanisms pre-existing)

| need                        | form                                    |
| --------------------------- | --------------------------------------- |
| or / not / single-event and | `await { it==:X or not(it==:Y) }`       |
| count / duration / sequence | `loop { _,dt = await('clock') ... }`    |
| temporal and (X then Y)     | `par_and(\ -> await'X', \ -> await'Y')` |
| temporal or (race)          | `par_or(...)`                           |

Derived clock — a plain function that loops on ticks:

    function clock (ms)
        local rem = ms
        while rem > 0 do
            local _, dt = await('clock')   -- tick carries dt
            rem = rem - dt
        end
        return 'clock', -rem               -- leftover, as before
    end

Tick source `emit('clock', dt)` is environment-side -> unchanged.

## Runtime changes (atmos/run.lua) — re-grep before editing

| # | place                                    | change                          |
| - | ---------------------------------------- | ------------------------------- |
| 1 | `M.await` @662-685                        | delete combinator dispatch      |
| 2 | `M.clock` @105 / `meta_clock` @82-103 / `clock_to_ms` @75-79 | delete all  |
| 3 | `check_ret` @545-556                      | delete `mta`/`mte` `__atmos`    |
| 4 | `await_to_table` @628-632                 | delete clock + `__atmos` cases  |
| 5 | `M.is` @144                               | delete `meta_clock` case        |
| 6 | `M.toggle` @828-831                       | filter is a plain predicate     |

After step 1, `await({'or'/'and'/'not',...})` tables are gone; control flows
straight to `await_to_table` (only `==` / func / bool / task / tasks remain).
After steps 3-6, `check_ret` is `bool` / `==` / `func` only; toggle filters
are inherently pure, so no `filter_is_pure` guard is needed.

## Library — derived clock

Home: a small module (e.g. `atmos/clock.lua`) or the atmos stdlib, NOT
`run.lua`.

Integration with `every` / `watching`, which expect an await-pattern value
(not a looping call):

- option A: `clock` returns a STREAM (`S.is`) so `await` / `every` /
  `watching` spawn it via the existing `S.is` path in `await_to_table`.
- option B: no clock value; write timing as explicit `loop` / `par_or`
  (`every` / `watching` sugar then does not apply to clocks).

## Language (atmos repo) — separate

- compile per-emit `==` / `or` / `not` / `and` to `{ it ... }` predicates.
- temporal `and` / `or` -> `par_and` / `par_or`.
- clock as stdlib (loop / await), per option A or B above.

## Out of scope / decisions

- keep `__atmos` as a dormant extension hook?  (this plan removes it.)
- `emit(clock{...})` object-emit form is dropped; only scalar
  `emit('clock', dt)` ticks remain.
- `par_or` / `par_and` behaviour unchanged.

## Checklist

- [ ] 1 — remove `M.await` combinator dispatch
- [ ] 2 — remove `M.clock` / `meta_clock` / `clock_to_ms`
- [ ] 3 — remove `check_ret` `__atmos` dispatch
- [ ] 4 — remove `await_to_table` clock / `__atmos` cases
- [ ] 5 — remove `M.is` clock case
- [ ] 6 — `M.toggle` plain-predicate filter
- [ ] 7 — derived clock module (option A / B decided)
- [ ] 8 — language: predicates + `par_*` + clock stdlib (separate)
