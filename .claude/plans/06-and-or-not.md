# and / or / not — passive event patterns (lua-atmos runtime)

## Scope

Restore `and` / `or` / `not` as passive primitives in the match engine
(`await_to_table` + `check_ret` + `check_task_ret`), so they work both in
`await` and in the `toggle` filter.
Revert-with-refinement of commit `bf6b9c2`.

Runtime-only (lua-atmos / `atmos/run.lua`).
Language keyword sugar is a separate atmos-repo concern (see §7).

## Background (history)

- `bf6b9c2` (May 26) removed passive `and`/`or` from `check_ret` /
  `check_task_ret` and routed `await({'and'/'or',...})` through
  `par_or` / `par_and`.
- `bcb0a29` (earlier) removed the `_and_` / `_or_` infix language sugar.
- The old passive `and` was STATEFUL across emits: it mutated `T[i]={'ok',...}`
  to remember matched branches, the same trick `clock` uses (`cur`). Proof:
  `emit('Y'); emit('X')` satisfied `{'and','X','Y'}` across two emits.
- Removal motivation was value semantics (rich per-branch tables -> flat
  single values), NOT feasibility. Flat returns are the keeper.

## Two families (the separation conflation destroyed)

- Passive event patterns (per-emit match, stateless or clock-style stateful),
  evaluated by `check_ret`:
  `==`, bool, func, clock, `not`, `or`, `and`.
- Structured concurrency over task BODIES (spawn + cancel losers), standalone
  functions only: `par_or`, `par_and`.

After this plan, `await({'and'/'or'/'not',...})` is passive matching again, and
`par_or`/`par_and` are reachable only as explicit calls.

-------------------------------------------------------------------------------

## Implementation steps (atmos/run.lua)

All line numbers are as of this writing; re-grep before editing.

### Step 1 — `check_ret`: add `or` / `and` / `not`

Location: `local function check_ret (T, ...)` @539.
Insert the new branch right after the two `__atmos` lookups, i.e. after
`local mte = getmetatable(...)` @543 and BEFORE `if mta and mta.__atmos` @545.
(`or`/`and`/`not` tables have no metatable, so the `__atmos` checks skip them;
their sub-patterns are recursed and may themselves be clocks.)

Add:

    if tp == 'not' then
        -- pure per-emit negation of the single sub-pattern
        return not (check_ret(T[2], ...))
    elseif tp == 'or' then
        -- first matching sub wins, returns its values
        for i = 2, #T do
            local vs = { check_ret(T[i], ...) }
            if vs[1] then
                return table.unpack(vs)
            end
        end
        return false
    elseif tp == 'and' then
        -- stateful across emits: remember matched branches (clock-style)
        -- store ONLY the first value per branch -> flat return
        for i = 2, #T do
            local vs = { check_ret(T[i], ...) }
            if vs[1] then
                T[i] = { 'ok', vs[2] }
            end
        end
        local ret = {}
        for i = 2, #T do
            if T[i][1] == 'ok' then
                ret[#ret+1] = T[i][2]
            else
                return false
            end
        end
        return true, table.unpack(ret)
    end

Note on flat semantics (the refinement): store `vs[2]` only (first value), so
`and` returns one value per branch. This reproduces the current tests (see
Step 6 regression anchors). Do NOT resurrect the old rich-table form.

### Step 2 — `check_task_ret`: add `or` / `and`

Location: `local function check_task_ret (T)` @526, currently only handles
`tp == '=='`. Insert before the final `else return false`.

Add:

    elseif tp == 'or' then
        for i = 2, #T do
            local chk,ret = check_task_ret(T[i])
            if chk then
                return chk, ret
            end
        end
        return false
    elseif tp == 'and' then
        local rets = {}
        for i = 2, #T do
            local chk,ret = check_task_ret(T[i])
            if chk then
                T[i] = { 'ok', ret }
                rets[#rets+1] = ret
            end
        end
        if #rets == (#T - 1) then
            return true, table.unpack(rets)
        else
            return false
        end

Note: original returned `true, rets` (a table); use `table.unpack(rets)` for
flat consistency with Step 1.

### Step 3 — `await_to_table`: build `or` / `and` / `not`

Location: `local function await_to_table (e, ...)` @614, inside the
`type(e) == 'table'` block. Insert BEFORE `elseif type(e[1]) == 'string'` @633
(otherwise `'and'`/`'or'`/`'not'` get caught by the generic string case).
Put it after the `__atmos` elseif @631-632.

Add:

    elseif e[1] == 'or' or e[1] == 'and' then
        T = { e[1] }
        for i = 2, #e do
            T[#T+1] = await_to_table(e[i])
        end
    elseif e[1] == 'not' then
        assertn(3, #e == 2, "invalid await : 'not' expects one argument")
        T = { 'not', await_to_table(e[2]) }

`T.time = TIME` @645 still runs at the end for the outer table — fine.

### Step 4 — `M.await`: remove the combinator dispatch

Location: `function M.await` @649. Delete the whole block @662-685 (the
`local v = ...`, the `if v=='or' or v=='and'` par-dispatch, and the
`elseif v == 'not'` branch). Let control fall straight through to
`t._.await = await_to_table(e, ...)` @687, which now builds the passive table.

Keep the `-- await({'or'/'and', ...})` doc line @656; add `-- await({'not',x})`.
`M.par_or` / `M.par_and` definitions are untouched (standalone only).

### Step 5 — `M.toggle`: reject stateful filters (DECISION)

Rationale: a toggle filter is a per-emit GATE; a stateful pattern is a footgun
(`{'and',A,B}` stays open forever once both have occurred; a clock advances on
every gated emit). Restrict filters to PURE per-emit predicates.

5a. Add a purity helper above `M.toggle` @796 (after `await_to_table`,
`meta_clock` is in scope):

    local function filter_is_pure (T)
        -- clock / custom stateful patterns carry __atmos state
        local mt = getmetatable(T)
        if mt and mt.__atmos then
            return false
        end
        local tp = T[1]
        if tp == 'and' then
            return false
        elseif tp == 'or' then
            for i = 2, #T do
                if not filter_is_pure(T[i]) then
                    return false
                end
            end
            return true
        elseif tp == 'not' then
            return filter_is_pure(T[2])
        else
            -- '==', 'bool', 'func' : pure per-emit predicates
            return true
        end
    end

(`func` runs user code per emit but is engine-stateless; allowed, same risk
profile as an `await` predicate.)

5b. In the off branch @828-831, assert purity:

    if filter.n > 0 then
        local f = await_to_table(table.unpack(filter, 1, filter.n))
        assertn(2, filter_is_pure(f),
            "invalid toggle : stateful filter")
        t._.filter = f
    end

Allowed filters: `==`, bool, func, `not`, `or` (all operands pure).
Rejected: clock, `and`, any `not`/`or` containing them.
This supersedes the "document the clock oddity" caveat in
`done/06-02-toggle-filter.md` @138.

-------------------------------------------------------------------------------

## Step 6 — Tests

### 6a. await semantics (tst/task.lua) — REGRESSION ANCHORS

These already exist and currently pass via par. After Steps 1-4 they must
STILL pass via passive matching (flat first-value-per-branch reproduces them):

- `await and 1` : `emit('Y',10); emit('X',20)` -> `"X\tY\n"` (temporal accum).
- `await and 5: clock` : `{'and','X', clock{s=1}}` -> `"X\tclock\n"`
  (clock as `and` operand is legal in AWAIT).
- nested `{'and', {'or','X',clock{s=1}}, {'or',ts,t}}` -> `"clock\ttrue\n"`.

Run them first; if they pass, the passive engine is value-correct.
Add if missing: an `await not` test (next non-matching emit awakes).

### 6b. toggle filter (tst/toggle.lua) `--- FILTER ---`

- filter 4 `not`: UNCOMMENT the assert at line 282 -> `"1\n2\n109\n"`.
- filter 5 `or` (passes): off with `{'or','Draw','Drag'}`; emit each ->
  both pass while off, a third event stays frozen.
- filter 6 `and` (ERROR): `pcall(function() toggle(t,false,{'and','A','B'}) end)`
  -> `assertfx(err, "toggle.lua:%d+: invalid toggle : stateful filter")`.
- filter 7 `clock` (ERROR): `toggle(t,false, clock{s=1})` -> same error.

### 6c. Run

    cd tst && lua all.lua    (user-run; do NOT auto-execute)

-------------------------------------------------------------------------------

## Step 7 — Language (atmos repo) — SEPARATE

- optional: restore `and`/`or`/`not` await keyword sugar
  (lexer/parser/coder) producing `{'and'/'or'/'not',...}` tables — the exact
  shape `await_to_table` now consumes.
- manual: document the two families (passive patterns vs `par_*`).

## Out of scope

- `par_or` / `par_and` behavior (unchanged).
- `with` syntax (separate plan).

-------------------------------------------------------------------------------

## Checklist

- [ ] Step 1 — `check_ret` or/and/not
- [ ] Step 2 — `check_task_ret` or/and
- [ ] Step 3 — `await_to_table` or/and/not build
- [ ] Step 4 — `M.await` remove combinator dispatch @662-685
- [ ] Step 5 — `M.toggle` filter_is_pure + reject stateful (5a, 5b)
- [ ] Step 6a — await regression anchors pass (tst/task.lua)
- [ ] Step 6b — toggle filter tests 4-7 (tst/toggle.lua)
- [ ] Step 6c — `cd tst && lua all.lua` green (user-run)
- [ ] Step 7 — language sugar + manual (atmos repo, separate)
