# Plan: rename `S.fr_await` -> `S.on`

## Status

DONE.

1. `S.fr_await` -> `S.on` across source, tests, examples, api.md,
   guide.md. HISTORY updated in place (v0.7 unreleased).
   Internal locals `fr_await`/`fr_spawn` left untouched.
2. `S.[x]paror` -> `S.[x]parany` (public + internal local), all
   sites + HISTORY.
3. api.md Sources rewritten: single `S.on(pat)` source mirroring
   all await patterns (was 3 pseudo-overloads), with the function
   spawn exception noted.

## Design conclusion (no further code change)

f-streams needs many `fr_*` because its pull-sources are
heterogeneous; atmos needs only ONE `S.on` because `await` already
unifies all 13 event forms. So no `on_*` family, no `on_task`.
`S.on(f)` keeps the spawn overload (the one form where `S.on`
diverges from `await`: function = spawn task, not predicate;
0 sites want predicate-fn streams, 11 want spawn).

## Follow-up

The `S.on(f,...)` / `await(f,...)` consistency gap is resolved
separately: see `260622-await-task.md` -- adds `await(f, ...)` =
spawn sugar to the runtime so `S.on` is a pure `await` forwarder.

## Context

`S.fr_await` is the stream constructor ("stream **fr**om await"):
a stream that repeatedly `await`s an event, fires on a clock period,
or spawns a task and awaits its result (RxJS `fromEvent`).

Rename the public name to `S.on`, which reads naturally for the
common event/time case (`S.on('click')`, `S.on(200*_ms_)`).

## Decision

- Single constructor, keep the overload (option 1).
    - `S.on(evt)`  -- stream of events
    - `S.on(dt)`   -- stream of periodic clock events (us)
    - `S.on(T,..)` -- stream of task `T` executions
- The task overload reads a bit loosely under `on`, but its
  semantics ("yield on each occurrence") still fit.
- Internal helpers `fr_await` / `fr_spawn` (local, mechanism names)
  stay as-is -- they honestly describe the await/spawn path.
  Only the public `S.fr_await` is renamed.

## Sites

Public symbol only: `S.fr_await` -> `S.on`. Internal locals untouched.

| file                              | count | place                       |
|-----------------------------------|-------|-----------------------------|
| atmos/streams.lua                 | 1     | `function S.fr_await` (def, line 20) |
| tst/streams.lua                   | 44    | test calls                  |
| tst/guide.lua                     | 2     | test calls                  |
| tst/readme.lua                    | 2     | test calls                  |
| atmos/env/clock/exs/hello-rx.lua  | 2     | example calls               |
| api.md                            | 3     | Sources (lines 449-453)     |
| guide.md                          | 5     | prose + examples (512-570)  |
| HISTORY.md                        | --    | add new entry (see below)   |

Internal-only (DO NOT rename): `atmos/streams.lua:11` local
`fr_await`, `:32` `f = fr_await`.

## HISTORY.md

Existing line records `S.from(clock) -> S.fr_await(<us>)`.
Do not rewrite history; append a new line:

    - `S.fr_await` -> `S.on`

## Steps

1. atmos/streams.lua: `function S.fr_await` -> `function S.on`.
2. swap all public call sites in tst/ and the clock example.
3. api.md: `S.fr_await(evt|T|dt)` -> `S.on(...)`.
4. guide.md: prose + examples (line 550 comment mentions
   `S.fr_await blesses it` -> `S.on blesses it`).
5. HISTORY.md: append the rename line.
6. confirm no remaining public `S.fr_await` (grep), leaving only
   the two internal locals in streams.lua.
