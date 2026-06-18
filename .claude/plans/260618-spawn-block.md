# Plan: rename `spawn_anon` -> `spawn_block`

## Status

DEFERRED -- not renaming now; the suite passes with `spawn_anon`.
Tracked separately from `260616-task-xtask` (the task/xtask split).

## Decision

Rename the public primitive `spawn_anon` -> `spawn_block`.

The internal mechanism (`tra=true`, transparent task) and the
close-only handle are unchanged: this is a pure name change.

## Rationale

`spawn_block` pairs cleanly with `spawn_task`:

| primitive       | spawns a...        | identity        |
|-----------------|--------------------|-----------------|
| `spawn_task`    | task               | yes (handle,    |
|                 |                    | `xtask()`,      |
|                 |                    | `await(t)`,     |
|                 |                    | `toggle`)       |
| `spawn_block`   | lexical block      | no (close-only  |
|                 |                    | handle)         |
| `spawn_in`      | task into a pool   | yes             |

- "block" implies a *structural, inline, non-referenceable* region,
  capturing exactly what the value is NOT: a first-class task you hold.
- "anon" undersells it -- anonymous functions are still first-class and
  referenceable; the point here is *no identity at all*.
- The returned close-only handle binds the body to a lexical block via
  `<close>`, so "block" fits doubly (it IS a block, and it scopes to
  one).

## Scope (mechanical: `spawn_anon` is a unique token)

Global rename `spawn_anon` -> `spawn_block`:

| file                       | sites                               |
|----------------------------|-------------------------------------|
| atmos/init.lua             | definition + comment                |
| tst/*.lua                  | proto, task, errors, thread, guide, |
|                            | + any others using it               |
| api.md                     | index entry, `## spawn_anon` header,|
|                            | anchor `#spawn_anon-f-`, body       |
| guide.md, tst/guide.lua    | all examples                        |
| .claude/plans/260616-...md | §2.2b / §2.2c references            |

A `sed -i 's/spawn_anon/spawn_block/g'` over the worktree covers it;
then fix the api.md anchor link (`#spawn_anon-f-` -> `#spawn_block-f-`).

## Steps

1. `sed` the rename across the files above.
2. fix the api.md TOC anchor for the section link.
3. run the suite; behaviour unchanged.

## Note

The ongoing "convert non-reused self-contained tasks to anon" pass
(in guide.md / guide.lua) is independent: it uses whatever the current
name is, and this rename sweeps it along.
