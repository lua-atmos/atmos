# Plan: Sync await pattern text (api.md <-> manual.md)

## Goal

Make the `await` pattern documentation share the **exact same text** in its
three parts: `pre` (intro sentence), `in` (pattern list), `pos` (closing
paragraph).

## Files

| file       | location                  | role                          |
|------------|---------------------------|-------------------------------|
| api.md     | this worktree             | Lua API ref (editable)        |
| manual.md  | /x/atmos-lang/atmos/doc/  | Atmos language ref (READ-ONLY,
              outside worktree, cannot edit) |

## Current state

### manual.md `### Await` (lines ~2093-2129)

- pre: "For the first format, a task awakes if an `emit(e,...)` matches the
  await expression patterns as follows:"
- in: Atmos-syntax list
    - `true` / `false` / `x, ...` / `c: clock` / `f: function` / `t: task`
    - `ts: tasks, ['any'|'all']`
    - `logical`: `{ 'not', x }` `{ 'and', ...}` `{ 'or', ...}`
    - `x: meta`
- pos: "The second format `await T(...)` spawns and awaits the given task to
  terminate. In this case, the `await` evaluates to the task final value."

### api.md `## await (pat)` (lines ~252-291)

- pre: "The task awakes when an `emit(e)` matches the given await pattern as
  follows:"
- in: Lua-table list (`{ tag='not', x }`) with 3 EXTRA rows not in manual:
    - `until|while`
    - `{ tag=t, ... }`
    - `x: any`
- pos: (none)

## Divergence (why "in" lists differ)

- api.md = Lua table API (`{ tag='not', x }`); manual = Atmos syntax
  (`!:X`, `{ 'not', x }`).
- api.md has 3 patterns manual lacks.

## Decision (2026-06-14): two-surface shared table

The Lua API and the Atmos language are DIFFERENT surfaces (`{tag='or'}`
vs `||`), so a concrete-syntax list can never be byte-identical. Instead
the `in` list is ONE shared block, fenced by markers, byte-identical in
both files: a fenced code block (so `||` pipes stay literal) with three
columns `Atmos | Lua | matches`. `pre`/`pos` stay per-side; api.md keeps
its Lua return-value/`__atmos` details in `pos`.

Canonical block (paste verbatim into BOTH files between the markers):

    <!-- AWAIT-PATTERNS: keep identical in lua-atmos/api.md and atmos-lang/doc/manual.md -->
    ```
    Atmos         Lua API                                 matches
    -----         -------                                 -------
    true          true                                    any event
    false         false                                   never
    5s            us: number                              after `us` microseconds (timer)
    —             'clock'                                 any bare-number clock tick
    \{…}          f: function                             when `f(e)` is truthy
    t             t: task                                 when task `t` terminates
    :any ts       { tag='tasks', mode='any', tasks=ts }   when any pool task terminates
    :all ts       { tag='tasks', mode='all', tasks=ts }   when all pool tasks terminate
    !p            { tag='not', x }                        when the event does not match `p`
    p1 && p2      { tag='and', … }                        when all sub-patterns match (any order)
    p1 || p2      { tag='or', … }                         when any sub-pattern matches
    p until c,…   { tag='until', x, … }                   re-awaits `p`, filtering until predicates
    p while c,…   { tag='while', x, … }                   re-awaits `p`, filtering while predicates
    [tag=:T, …]   { tag=t, … }                            when the tag and every field match
    x             x: any                                  when `e` is equivalent to `x`
    —             x: meta                                 custom `__atmos(x,e,…)` (runtime-only)
    ```
    <!-- /AWAIT-PATTERNS -->

Notes:
- `—` cells = no clean surface on that side (clock-tick / `__atmos` are
  lua-atmos runtime-level). The atmos-lang owner confirms/fills the Atmos
  column when pasting (esp. these two rows).
- This also FIXES the manual's stale list: positional `{'not',x}` ->
  combinators, adds clock-tick / `until`-`while` / meta coverage.

## Status

- [x] Located both await sections
- [x] Diffed pre / in / pos
- [x] Decide sync scope -> two-surface shared table (option above)
- [x] Apply to api.md (this worktree): fenced block + Lua-detail `pos`
- [ ] Apply SAME block to manual.md (atmos-lang) -- CANNOT edit from here;
      tracked under atmos-lang `.claude/plans/06-11-await.md` "Manual
      combinator subsection". Sequence: land there, then both are in sync.
