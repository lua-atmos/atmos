# Plan: Reject `await(function)` in `M.await` (lua-atmos runtime)

## STATUS -- DONE (lua-atmos); `.atm` deferred to atmos-lang barrier

- §1 runtime guard: DONE. Final message is
  `invalid await : unexpected function` (not the draft text).
- §2 `.lua` callers: DONE + re-tested -- birds 05-11 lambdas,
  rocks `ts.lua` named `out_of_screen` (grep-missed, caught at
  runtime), pingus `await(f)` (earlier). task.lua handled.
- §2.1/§2.2 `.atm` + §3 atmos-lang suite: NOT this repo -- tracked
  under the atmos-lang v0.7 barrier (separate session).
- Ships in `0.7-2` via branch-tracking (no new rev). Pending push:
  atmos `v0.7`, sdl/pico-birds, sdl/pico-rocks.

## Context

`run.lua` `M.await` still accepts a BARE FUNCTION as an await pattern: at
the general matcher (`run.lua:~597`) it does `if type(awt)=='function'
then awt(emt) ...`, i.e. a function silently acts as a re-checked
predicate. This is LEGACY behavior.

`api.md` (await patterns table) NO LONGER documents a `function` row --
only `T: task` / `t: xtask` (Tasks group), `{tag='until'/'while'}`
predicates, value/boolean/time/meta. We want to REJECT a function passed
directly to `await`, to avoid confusion with the `await(T, ...)` task
spawn-and-await form.

KEY INSIGHT (why this is a one-line guard): the `until`/`while` predicate
forms wrap the function in a TABLE (`{tag='until', f}`). At `M.await`
ENTRY `awt` is that table, so a top-of-function `type(awt)~='function'`
assert PASSES. The function only appears LATER, when the base-less
`until`/`while` branch reassigns `awt=f` and falls through to the `:597`
matcher -- which is AFTER the entry assert, in the same call. So a single
entry assert rejects DIRECT `await(f)` without touching predicate logic.

## §1. The change (`run.lua`, `M.await`)

- [x] Add at the TOP of `M.await`, grouped with the existing input
      guards (after the `tasks`-pool assert ~`:501`, BEFORE
      `local tag = ...` ~`:503`):

```lua
assertn(2, type(awt) ~= 'function',
    "invalid await : function not allowed (use until/while)")
```

- [x] DO NOT change the `until` / `while` / function handling inside
      `M.await` (the `:527` branch and the `:597` `type(awt)=='function'`
      matcher stay AS-IS). The entry assert alone does the rejection;
      predicate forms still reach `:597` via table-wrapped dispatch.
- [x] Verify: `await(\{...})` / `await(f)` -> rejected with the message;
      `await until \{...}` / `await(:X until \{...}` -> still work.

## §2. Audit all callers (`/x/lua-atmos/*` + `/x/atmos-lang/*`)

Every DIRECT function/lambda predicate to `await`/`watching` breaks and
must move to `until` (predicate) -- `watching \{c}` -> `watching until
\{c}`. Named `func` predicates (`watching out_of_screen`) likewise.
Watching a VALUE (task/xtask/tasks/stream/event) is UNAFFECTED.

Seeded from grep (CONFIRM each + finish the sweep):

### 2.1 `.atm` -- bare-lambda `watching \{...}` (BREAKS -> `until`)

| repo / file | lines |
| ----------- | ----- |
| sdl-birds: birds-05/06/08/09/10/11 | `\{xx>640}`, `\{rect.x>640}`, `\{rect.y>(480-H)}` |
| pico-birds: birds-05/06/08/09/10/11 | `\{xx>1}`, `\{rect.x>1}`, `\{rect.y>0.9}` |

### 2.2 `.atm` -- named-`func` predicate (BREAKS -> `until`)

| repo / file | line | note |
| ----------- | ---- | ---- |
| sdl-rocks/ts.atm | 26 | `watching out_of_screen` (`out_of_screen = func()`) |
| pico-rocks/ts.atm | 25 | `watching out_of_screen` |

### 2.3 `.atm` -- NOT affected (watching a value, verify quickly)

- `watching bird` (xtask), `watching ships`/`:any ships` (pool),
  `watching ctl`/`watching src` (clicks.atm: streams/events).
  NOTE pico-rocks/battle.atm:56 `watching ships` lacks `:any`/`:all` --
  separate UNMIGRATED bug, not this plan.

### 2.4 `.lua` -- direct function awaits (CHECK)

| file | line | note |
| ---- | ---- | ---- |
| lua-atmos/atmos/tst/task.lua | 37 | `await(function () end, 'A')` -- runtime's own test; update or assert-rejects |
| atmos-lang/atmos/src/prim.lua | 237 | FALSE POSITIVE -- parser plumbing, not a runtime await |

- [x] Finish sweep of remaining `.lua`: `S.on(<func>)` streams,
      `par_*`, env code, all `tst/*.lua` -- anything passing a bare
      function where a pattern is expected.
      (Done: only `out_of_screen` ×2 beyond the birds lambdas; all
      other identifier-first-args are tasks/streams/values/booleans.)
- [x] For each real hit: rewrite to `until`/`while`, or (in tests)
      assert the new rejection.

## §3. Test reminder (DEV runs; Claude never runs)

After §1 + §2:

- [x] lua-atmos: run its normal test suite. (passes)
- [ ] atmos-lang: `cd tst && lua5.4 all.lua`. (atmos-lang session / barrier)
- [x] Application repos -- run entry points (migrated predicates must use
      `until` now): ran the `.lua` entry points (`.atm` are atmos-lang)
    - sdl-birds `birds-11.lua` (06,11), sdl-rocks `main.lua`
    - pico-birds `birds-11.lua` (05,11), pico-rocks `main.lua`
    - sdl-pingus `main.lua`
- [x] Confirm the rejection message fires on a deliberate `await(\{...})`.
      (4 rejection tests in `tst/await.lua`)

## Notes

- This is a RUNTIME change (lua-atmos), separate from the atmos-lang
  v0.7 compiler release. Decide: v0.7 blocker vs v0.7.1 follow-up. The
  compiler dep `atmos ~> 0.7` still resolves either way.
- Compiler-side (atmos-lang) could ALSO reject `await <lambda>` /
  `watching <lambda>` at parse for a nicer message -- OPTIONAL; keep the
  runtime as the single source of truth unless wanted.
