# Plan: `where` await combinator

- Date: 2026-06-05
- Branch: 06-and-or-not

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

- [ ] tests in `tst/await.lua`
- [ ] `where` branch in `run.lua`
- [ ] doc: `api.md` await patterns + `guide.md`

## Open items

- multi-value return arity for non-event `pat`.
- `nil` predicate result == `false` ? (assumed yes).
- compiler desugar + implicit predicate binding name.
