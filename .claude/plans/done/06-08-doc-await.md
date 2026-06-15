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

## Decision (2026-06-14): per-doc `Pattern` table, mirrored semantics

The Lua API and Atmos are DIFFERENT surfaces (`{tag='or'}` vs `||`), so
each doc shows ONLY its own surface, as a single `Pattern` column.
(Marker comments were dropped; the table just sits under the `pre` line.)
Layout (both files):

    | Group | Pattern | matches | returns |

- `Pattern` = THIS doc's surface (Lua in api.md, Atmos in manual.md).
- `Group | matches | returns` MIRROR across both files -- keep these in
  sync; the block is NOT byte-identical anymore (only these 3 columns).
- Rows grouped+reordered: Boolean, Value (`[tag=:T]`/`{tag=t}` + `x`, both
  `M.is`-based), Time, Tasks, Condition (function + `until`/`while`),
  Logical, Meta (`__atmos`, last). `Group` label on each group's first
  row, blank below (markdown approx of a rowspan).
- TABLE-ONLY: `until`/`while` semantics live in their `matches` cells; no
  `pos`. Only `pre` stays per-side.

Conventions:
- ASCII `...` (not `…`); `(none)` Pattern = no surface on that side
  (only the clock-tick row is `(none)` in manual.md; Meta uses `mt`).
- `or` row escapes the pipe: `` `p1 \|\| p2` `` (GFM renders `||`).
- `returns` = Lua/runtime tuples (`v,t,ts`); Atmos `await` evaluates to
  the single event value (manual line 2087 already states this).

This also FIXES the manual's stale list: positional `{'not',x}` ->
combinators, adds clock-tick / `until`-`while` / meta coverage.

## Status

- [x] Located both await sections
- [x] Diffed pre / in / pos
- [x] Decide sync scope -> two-surface shared GFM table (option above)
- [x] Apply to api.md (this worktree): GFM table + Lua-detail `pos`
- [x] Apply SAME block to manual.md (atmos-lang `v0.7`): replaced the old
      bulleted list at `doc/manual.md:2092`; `diff` of the two
      AWAIT-PATTERNS blocks = IDENTICAL; both render (pandoc) with `||`
      restored + 4 columns. Manual keeps its own `pre`/returns caveat.
      NOTE: manual.md edit is UNCOMMITTED on atmos-lang `v0.7`.

PLAN COMPLETE.
