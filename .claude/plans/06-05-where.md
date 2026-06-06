# Plan: `until` await combinator

- Date: 2026-06-05
- Branch: 06-and-or-not
- NOTE (2026-06-06): renamed `where` -> `until` (body below predates the
  rename; tag is now `{ 'until', x, f... }`). `while` (negated gate) is a
  possible follow-up, not yet implemented.

## Goal

Add a `where` combinator beside `or` / `and` / `not`, to await an
event matching a pattern *and* satisfying trailing predicates.
Restores the ergonomic `await(:X, pred...)` form lost when `await`
moved to a single pattern.

## Why `where` (not `and` + predicate)

`and` / `or` desugar to `par_and` / `par_or` of independent
sub-awaits (`run.lua:517`): each branch matches its own, possibly
different, emit.
`where` requires the *same* matched event to also satisfy the
predicates, which `and` cannot express.

## Surface

    await(pat, e1, e2)
      -> await({ tag='where', <pat>, <e1>, <e2> })

- `pat`  | any await pattern (tag, `true`, `or`/`and`/`not`, clock,
           task, ...): full runtime matching is reused.
- `ei`   | predicate functions of the matched event.

The compiler desugar (implicit predicate binding) is a separate
layer, out of scope here; tests drive the raw table form.

## Semantics

Each predicate is called with the matched event.

- gating: if any predicate returns `false`, reject and re-await the
  next match.
- result: the *last* predicate decides the return value.

| last pred returns | result          |
| ----------------- | --------------- |
| `false`           | reject, re-await |
| `true`            | the event       |
| `x`               | `x`             |

- earlier predicates only gate (their non-`false` value is ignored).
- zero predicates: reject as invalid (error).
- `nil`: treated as `false` (reject) — pin at impl time.

## Post-yield property (no spin)

Event patterns have no pre-yield branch, so `M.await(pat)` resolves
only after a real `coroutine.yield()`.
Thus a failing predicate always round-trips a yield: no infinite
loop, no `TIME` guard needed.
Caveat: `where` over an immediately-matching pattern (terminated
task / tasks) is out of scope; `where` is an event filter.

## Runtime impl (sketch, `run.lua`, beside `or`/`and`/`not`)

    elseif tag == 'where' then
        -- assert at least one predicate, else invalid
        while true do
            local it = M.await(awt[1])      -- full matching reused
            local res, ok = it, true
            for i = 2, #awt do
                local r = awt[i](it)
                if r == false then
                    ok = false
                    break
                end
                -- last predicate decides the result
                if i == #awt and r ~= true then
                    res = r
                end
            end
            if ok then
                return res
            end
        end
    end

Open: preserve multi-value returns of `M.await(pat)` (clock / task /
tasks) vs single `it`; current sketch keeps single value.

## Validation

`tst/await.lua`, `_WHERE_` section (appended at end).

## Status

- [x] tests in `tst/await.lua` (`_WHERE_`, 8 cases)
- [x] `where` branch in `run.lua` (falsy gate, last pred decides)
- [x] sync `assertn` msg -> `expected predicate`
- [x] failing tests: nested-emit shadowing
    - `where 9`: `emit_in('global',{X,2})` (P may terminate; tag-filtered)
    - `not 3`: `emit_in('global','Y')` + park `P` (avoid term event)
- [x] fix: pin establishment time via `M.await(time, awt, ...)` param
    - `time` is 1st arg, required (no default); stamp `me._.time = time`
    - counter is `M.TIME` (was file-local); exposed as `run.TIME`
    - `where`/`not` thread `time` into every re-await (incl. `par_or` children)
    - `or`/`and`/`S.is` forward `time`
    - public `await` wraps `run.await(run.TIME, awt, ...)`
    - non-pinning internal `M.await` calls pass `M.TIME`
    - `every`/`watching` pass `M.TIME` (avoid swallowing tasks `mode`)
- [x] ALL TESTS PASS (full suite)
- [x] doc: `api.md` await pattern list (`until`, own bullet)
- [x] rename `where` -> `until`
- [x] add `while` (negated gate); merged with `until` in one branch
    - accept: `until` when all preds hold; `while` when any fails
    - `until` value-replaces (last pred); `while` returns the event
    - tests 1/2/5 switched until->while; ALL PASS
- [x] `api.md`: add `while` bullet (beside `until`)

## tasks-pool await: mandatory tagged form (2026-06-06)

`await(ts[,mode])` replaced by `{ tag='tasks', mode='any'|'all', tasks=ts }`.
- mode mandatory; carried in-pattern so it composes in `or`/`and`/etc.
- `M.await`: dropped positional `mode`/`meta_tasks` top-block; bare `ts` -> error;
  new `tag=='tasks'` validate-branch + pool-state check on `awt.tasks`.
- migrated 10 sites: `streams.lua:219`; `await.lua` x3; `tasks.lua` x6.
- bad-mode error keeps msg `invalid await : expected 'any' or 'all'`.

## Time-shadowing bug (where/not)

A rejected internal re-await re-stamps `me._.time` (`run.lua:568`) to
the now-higher global `TIME`, shadowing an in-flight outer emit at a
lower dispatch-local `time` (`:714`).
User loops are correct (they matched, from the user's view);
`where`/`not` reject invisibly, so their establishment time must not
advance.
Fix scope: `where` + `not` only.
`not` (and `where` over `or`) re-await via `par_or` sub-tasks, so the
pin must reach spawned children.

## Open items

- multi-value return arity for non-event `pat`.
- `nil` predicate result == `false` ? (assumed yes).
- compiler desugar + implicit predicate binding name.
