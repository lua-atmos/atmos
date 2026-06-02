# Toggle Filter — lua-atmos runtime

## Scope

Runtime-only (lua-atmos).
Add an optional event filter to `toggle`, so a toggled-off task (or block)
still reacts to events matching a pattern.

This plan is NOT about the language.
The Atmos `with` syntax (lexer/parser/coder/manual) is a separate plan in the
`atmos` repo.
Here the runtime API is positional varargs only; there is no syntax.

## Target file

`atmos/run.lua` only.
`atmos/init.lua` needs no change.
`toggle = run.toggle` @61 is a direct reference, so extra varargs flow through.

## Runtime API

Task form:

    toggle(task, false, pat...)   -- off, but events matching pat still pass
    toggle(task, true)            -- on (clears the filter)

Block form (derived):

    toggle(tag, body, pat...)     -- tag toggles on/off; pat passes while off

`pat...` follows the exact `await` convention (same `await_to_table` /
`check_ret`).
To match "A or B" use a predicate, not multiple args.
Multiple args keep their `await` meaning (positional per-emit-argument match).

## Current behavior (run.lua)

- `M.toggle (t, on)` @793:
    - string `t` -> derived block form: spawns body + a controller that loops
      `await(e,false); toggle(t,false); await(e,true); toggle(t,true)` @800.
    - else sets `t._.status = 'toggled'` (off) / `nil` (on) @815-822.
- `emit (time, t, ...)` @739 short-circuits the WHOLE subtree when toggled:

        if t._.status == 'toggled' then return ok, err end       -- @742-744

  Neither the descendants nor the task itself receive the event.
- Match engine:
    - `await_to_table (e, ...)` @614 builds the pattern table `T`.
    - `check_ret (T, ...)` @539 tests `T` against the event args
      (tags via `_is_`, booleans, funcs, clocks via `__atmos`).

## Design

Store the filter pattern on the task and gate the toggled short-circuit with it.

### 1. State

Add `t._.filter`: a `T` table produced by `await_to_table`, or `nil`.
It is orthogonal to `t._.status` and is consulted only while
`status == 'toggled'`.
No change needed in `M.task` @445 (the field defaults to `nil`).

No reentrancy/stacking: `filter` is 1:1 with `status` (set on OFF, cleared on
ON), and `status` cannot nest (asserts @816/@819 reject double-off/double-on),
so no save/restore is needed.
Nested tasks each own their `filter`; `emit` reads each level independently.
Only the clock-pattern caveat applies (see Edge cases @138).

### 2. Gate in `emit` (@742)

Replace the unconditional return with a filter test.
Toggled AND filter matches -> fall through to normal delivery (recurse into
`dns`, then resume self if its own await matches).
Toggled AND no match -> return as today.

    if t._.status == 'toggled' then
        if not (t._.filter and (check_ret(t._.filter, ...))) then
            return ok, err
        end
    end

`check_ret` is the local @539, in scope at `emit` @739.
The parens take only its first return (`false` | `true`).
The recurse/resume logic below @746-775 is unchanged.

### 3. `M.toggle` accepts and stores the filter

    function M.toggle (t, on, ...)
        -- block form: forward the filter to the derived toggle(bt,false,...)
        if type(t) == 'string' then
            local e, f = t, on
            local fil = table.pack(...)
            do
                local bt <close> = M.spawn(..., true, f)
                local _  <close> = M.spawn(..., true, function ()
                    while true do
                        M.await(e, false)
                        M.toggle(bt, false, table.unpack(fil, 1, fil.n))
                        M.await(e, true)
                        M.toggle(bt, true)
                    end
                end)
                return M.await(bt)
            end
        end
        ...
        if on then
            t._.status = nil
            t._.filter = nil
        else
            t._.status = 'toggled'
            local fil = table.pack(...)
            t._.filter = (fil.n > 0)
                and await_to_table(table.unpack(fil, 1, fil.n))
                or nil
        end
    end

`await_to_table` is the local @614, already in scope for `M.toggle` @793.
Build the filter table at toggle-off time so `T.time = TIME` is fresh.

## Why the subtree gate is enough

A "freeze but keep drawing" entity is typically:

    par { every :Draw {...} } with { every :Tick {...} }

Toggling the parent off normally blocks the whole subtree.
With filter `:Draw`, an `emit(:Draw)` passes the gate, recursion reaches the
`every :Draw` child, its await matches, and it draws.
`emit(:Tick)` is gated out and the entity stays frozen.

The filter need NOT match the task's own await; it gates the subtree, and the
existing per-task await-matching resumes whichever descendant cares.
An event the filter passes but no descendant awaits simply re-yields (via
`awake` @598 / `check_ret`), so it is harmless.

## Edge cases and caveats

- No filter -> `t._.filter == nil` -> today's behavior exactly.
- `toggle(t, true)` clears both `status` and `filter`.
- Predicate filter runs user code during broadcast: same risk profile as an
  `await` predicate, now per-emit per-toggled-task.
- Clock as a filter is legal but odd: `check_ret`'s `__atmos` mutates `cur`
  on each emit. Document; do not special-case.
- Pools (`meta_tasks`) accept toggle today; the same gate applies (filter
  stored on the pool, checked in `emit`).

## Out of scope (separate atmos-repo plan)

- `with` keyword parsing in `src/prim.lua` (task + block forms).
- Passing the pattern through `src/coder.lua` as extra `toggle(...)` args.
- `doc/manual.md` grammar, semantics, and examples.
