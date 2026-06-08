# Plan: Clock await patterns as plain numbers (microseconds)

## Idea

`await(<number>)` where the number is a clock duration in **microseconds**.
Drop the `clock{...}` table form entirely.

```
await(5 * _s_)      ;; wait 5s
await(500 * _ms_)
```

## Worktree model (06-and-or-not branch)

NOTE: edit only files under `.work/06-and-or-not/` (the main checkout at
`/x/lua-atmos/atmos/` is a separate, diverged tree -- do NOT touch).

- clock value = plain table `{ tag='clock', ms=N }` (NO metatable).
- `M.await` (`atmos/run.lua`) is one unified function:
    - `tag = (table and awt.tag) or awt`
    - clock setup `awt._ms = awt.ms`; awake when `awt._ms<=0` returns
      `'clock', -awt._ms, awt._now`; tick subtracts `emt.ms`.
- tick event = single table `emit{ tag='clock', ms=dt, now=now }`.
- clock env emits ms (`os.clock()*1000`).
- a bare number currently hits the final `M.is(emt,tag)` equality branch.

## Decisions (locked)

1. Microseconds everywhere (rename `ms` field -> `us`, `_ms`/`_now` ->
   `_us`/`_now`).
2. Breaking: bare `await(<number>)` = clock duration; no longer matches
   `emit(<number>)` by equality.
3. Numbers-only: remove `M.clock` constructor + `clock` global.

## Constants (new, base unit = us)  -- `atmos/init.lua`

| name    | value         |
|---------|---------------|
| `_us_`  | `1`           |
| `_ms_`  | `1000 * _us_` |
| `_s_`   | `1000 * _ms_` |
| `_min_` | `60 * _s_`    |
| `_h_`   | `60 * _min_`  |
| `_day_` | `24 * _h_`    |

## Edits

### Core
- `atmos/run.lua`
    - remove `M.clock` (78-89).
    - `M.await`: after `tag` line, add
      `if type(awt)=='number' then awt={tag='clock',us=awt}; tag='clock' end`.
    - rename clock internals `ms`->`us`: setup, awake-return, tick-subtract.
- `atmos/init.lua`: drop `clock = run.clock`; add `_us_.._day_`.
- `atmos/env/clock/init.lua`: `os.clock()*1000000`, emit `us = now-old`.
- `atmos/streams.lua`: `_is_(v,'clock')` -> `type(v)=='number'`.

### Conversions (clock{...} -> number consts)
- `clock{s=N}`  -> `N*_s_`,  `clock{ms=N}` -> `N*_ms_`,
  `clock{h=1,min=1,s=1,ms=10}` -> `1*_h_ + 1*_min_ + 1*_s_ + 10*_ms_`,
  `clock{ms=ms}` -> `ms*_ms_`.
- tick emits: `emit(clock{h=10})` -> `emit{tag='clock', us=10*_h_}`;
  `emit{tag='clock', ms=N, now=M}` -> `emit{tag='clock', us=N*_ms_, now=M}`.

### Tests / examples / docs
- tst: `await.lua`, `task.lua`, `guide.lua`, `readme.lua`, `envs.lua`.
    - overshoot assert: `await.lua` "or 5" `25` -> `25000` (us scaling).
- exs: `env/clock/exs/hello.lua`, `hello-rx.lua`.
- docs: `api.md`, `README.md`, `guide.md`, `env/clock/README.md`,
  `env/README.md`.

## Follow-up: symmetric number ticks (revoke evt.now)

Emit side now mirrors the await side: a clock tick is a **bare number** of
elapsed microseconds, not a `{tag='clock', us, now}` table.

- `env/clock/init.lua`: `emit(now - old)` (still tracks `M.now`).
- `run.lua` await loop: tick branch `if type(emt)=='number' then awt._us -= emt`.
- awake return drops `now`: `'clock', overshoot` (was `..., now`).
- `evt.now` revoked -- apps read absolute time via `env.now`.
- test ticks simplified: `emit{tag='clock', us=N, now=M}` -> `emit(N)`
  (task.lua, await.lua, envs.lua).
- docs: api.md await row (`returns 'clock', overshoot`), env/README.md
  (`emit(dt)`).

## Status

- [x] Mapped worktree clock model (run.lua/init/env/streams)
- [x] Core edits (run.lua remove M.clock + number branch + ms->us;
      init.lua consts; env us; streams number)
- [x] Conversions in tst/ (task, await, guide, readme, envs) + exs/
- [x] Docs (api.md row + consts table; READMEs; guide.md)
- [x] Parse-check (luac -p) all edited lua OK
- [x] Full test suite passes (user-run)

## Notes

- `await(<number>)` no longer matches `emit(<number>)` (breaking, intended).
- overshoot now scales x1000 (await.lua "or 5": 25 -> 25000).
- consider a HISTORY.md entry (clock now number/us) -- not done.
- breaking-change fallout found at runtime: `tst/tasks.lua` used numeric
  events via `await(v)` (v=1,2,3) matched by `emit(v)`. Migrated the event
  vehicle to strings (`await('e'..v)` / `emit('e2')`) while keeping numeric
  returns, so pool any/all asserts are unchanged. Other numeric `emit(n)` in
  `task.lua` are consumed by `await(true)`, so unaffected.
- runtime fallout 2: `tst/errors.lua` "clock external error" used the spaced
  form `clock {h=0,..,ms=1}` (my first sweep grepped `clock{` w/o space).
  -> `1*_ms_`. env `init.lua:12` (emit) line unchanged so the trace asserts.
- runtime fallout 3: STREAMS. `S.from(<number>)` is a base f-streams numeric
  range/counter (e.g. `S.from(1,3)`, `S.from(1)` for zip), so a number cannot
  be overloaded as a clock. Removed the `S.from` clock override in
  `atmos/streams.lua`; clock streams now call `S.fr_await(<us>)` directly
  (which is what `S.from(clock)` expanded to anyway). Migrated readme.lua and
  hello-rx.lua clock streams; updated api.md streams source doc.
