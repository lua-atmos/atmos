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

## Open decision (asked, deferred to this plan)

Scope of sync:
1. pre+pos prose only (keep api.md list as-is)
2. all 3 parts verbatim (drops api.md extra patterns + table forms)
3. reconcile both ways (blocked: manual.md is outside worktree)

## Status

- [x] Located both await sections
- [x] Diffed pre / in / pos
- [ ] Decide sync scope (option 1/2/3)
- [ ] Apply edits to api.md
