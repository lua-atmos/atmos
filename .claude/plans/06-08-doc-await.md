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
both files: a GFM TABLE with four columns
`Group | Atmos | Lua API | matches | returns`, source-aligned. Rows are
grouped+reordered: Boolean, Value (`[tag=:T]` + `x`, both `M.is`-based),
Time, Tasks, Condition (function + `until`/`while`), Logical, Meta
(`__atmos`, last). The `Group` label sits
on each group's first row, blank below (markdown-native approx of a
rowspan). TABLE-ONLY: `until`/`while` semantics live in their `matches`
cells; no `pos`. Only `pre` stays per-side. (The `or` row's `\|\|` escape
makes that one cell 1 char wider -- unavoidable.)

CANONICAL BLOCK = the table in `api.md` between the
`<!-- AWAIT-PATTERNS ... -->` markers (single source of truth -- do NOT
duplicate it here; copy it from there to avoid drift).

Table conventions (so it stays copy/paste-identical):
- ASCII only: `...` (not `…`), `(none)` for an absent surface (clock-tick
  / `__atmos` are lua-atmos runtime-level).
- the `or` row escapes the pipe: `` `p1 \|\| p2` `` (GFM renders `||`).
- the atmos-lang owner confirms/fills the Atmos column when pasting (esp.
  the two `(none)` rows).
- the `returns` column is Lua/runtime tuples (`v,t,ts`); Atmos `await`
  evaluates to the single event value -- note this on the manual side.

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
