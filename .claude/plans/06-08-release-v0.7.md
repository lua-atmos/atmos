# Plan: Release v0.7 (next rev)

## RESUME HERE (state @ 2026-06-18) -- NEXT = §2 (docs re-sync)

PRIOR CUT (frozen, do NOT redo): rock `atmos-0.7-1` was
published 2026-06-09 from `a5fc70e` (main), together with
env-sdl `v0.2`, env-pico `v0.3`, env-socket `v0.2`,
env-iup `v0.2`, and the 5 apps. That cut was never announced
(§8 stayed open), so it never reached users.

Since 0.7-1, the `v0.7` branch grew ~85 commits of further
breaking changes (see "New since 0.7-1" below) that are NOT in
the published rock and NOT in HISTORY.md. This plan is reset to
re-cut the release including them.

>>> NEXT — §2: re-sync the docs.
    - HISTORY.md is missing the 4 entries listed in §2.2.
    - api.md already carries the new API; guide.md needs a pass.
    Then: §3 bump the rockspec rev, §1 re-run tests, §5 re-merge
    + push, §6 re-publish, §7 remote verify, §8 announce.

Still pending from the prior cut (carry forward):
- §4.5 env-js: POSTPONED (gated on `atmos-lang/atmos` v0.7).
- §7 remote verify, §8 announce: never done.

## Context

Atmos v0.6 extracted all envs (except clock) to separate repos.
v0.7 is mostly a core/language refactor with breaking changes to
`await`/`emit`, the clock, and the environment API.
This plan uses release branches (not tags) for versioning.

New since 0.7-1 (NOT yet in HISTORY.md):

- Additions:
    - `task` / `xtask` / `tasks`: prototype vs instance vs pool
    - `spawn` / `spawn_in` / `do_spawn`: spawning API
        - `do_spawn(f)` returns a close-only `<close>` handle
- Modifications:
    - `every` -> `loop_on`
    - `atmos.x` (`X`) consolidation: `is`, `eq`, `xin`, `cat`,
      `gte` moved/folded into `x.lua`

Already shipped in 0.7-1 (for reference, in HISTORY.md):

- Additions:
    - `abort` task and tasks
    - `await(ts, ['any'|'all'])`: await any/all tasks in a pool
    - `toggle(..., [filter], ...)`: optional filter pattern
    - Logical combinators: `{ tag='or'/'and'/'not', ... }`
    - `__atmos` metamethod: custom await matching
- Removals:
    - Multi-arg events (`emit`/`await` single arg only)
    - `_and_` / `_or_`
- Modifications:
    - `emit('X', 10)` -> `emit { tag='X', v=10 }`
    - `clock { ... }` -> `dt` in microseconds
        - `await(5 * _s_)`; constants `_us_ _ms_ _s_ _min_ _h_ _day_`
        - `S.from(clock)` -> `S.fr_await(<us>)`
- Environments:
    - `open`+`close` -> main body + `quit`
- Bug fixes:
    - `break()` inside `every` (now `loop_on`)

## Steps

### 1. Run tests

- [ ] Automatic tests: all pass

```bash
cd tst && lua5.4 all.lua
```

- Manual tests:
    - [ ] README.md
    - [ ] guide.md

### 2. Docs

- [ ] Check if all docs are consistent:

- README.md
- guide.md
- api.md
- HISTORY.md

#### 2.1 README.md

Examples use `_s_` (v0.7-clean). Re-check for the new API
(`spawn`/`do_spawn`, `loop_on`) and version strings.

- [x] Re-check examples against new API (`every` -> `loop_on`)
- [x] Confirm version strings still correct (v0.7 stable)

#### 2.2 HISTORY.md (MISSING the post-0.7-1 entries)

Add under v0.7 (these 4 are not yet recorded):

- [x] Additions: `task`/`xtask`/`tasks`; `spawn`/`spawn_in`/`do_spawn`
- [x] Modification: `every` -> `loop_on`
- [x] Modification: `atmos.x` (`X`) consolidation
- [x] Fix the stale `break() inside every` line (now `loop_on`)

#### 2.3 Rockspec description

- [x] Re-confirm `detailed` matches README: fixed `every` ->
      `loop_on` in `atmos-dev-2.rockspec`. `atmos-0.7-1.rockspec`
      left frozen; §3 new rev must carry `loop_on`.

#### 2.4 guide.md

Migrated for 0.7-1 (clock `dt`/`_s_`, `abort`, `toggle`,
`fr_await`). Now needs a pass for the new API:

- [x] `spawn(task(...))` / `do_spawn(...)` usage consistent
- [x] `every` -> `loop_on` everywhere
- [x] `task`/`xtask` terminology aligned with api.md

#### 2.5 api.md (already ahead -- verify only)

Verified present (0.7-1): single-arg `emit`/`await`,
`{tag='tasks', mode='any'/'all'}`, `dt`/constants, `abort`,
`toggle`, `{tag='or'/'and'/'not'}`, `__atmos`, env `quit`,
`S.fr_await`.

New API also present: `task`/`xtask`/`tasks`, `spawn`,
`spawn_in`, `do_spawn`, `loop_on`, `X` helpers.

- [x] Final consistency pass vs guide.md (added backticks to
      `toggle (tsk, on)` header; `emit_in` left guide-undocumented)

### 3. Rockspec

New rev required: luarocks.org rejects overwriting a published
version, so the `every`->`loop_on` description fix can only ship
via fresh revisions.

- [x] Create `atmos-0.7-2.rockspec` (copy of 0.7-1, `loop_on`
      fix, `source.branch=v0.7` kept). 0.7-1 left untouched.
- [x] Create `atmos-dev-3.rockspec` (replaces dev-2; `loop_on`
      fix; dev-2 removed -- single dev spec convention).
- [ ] Install locally (`luarocks make atmos-0.7-2.rockspec`)

### 4. Release all environments and apps

PRIOR CUT (all DONE + published for 0.7-1):

- [x] `env-sdl`    `v0.2`, rock `0.2-1`, apps `v0.5`
- [x] `env-pico`   `v0.3`, rock `0.3-1`, apps `v0.6`
- [x] `env-socket` `v0.2`, rock `0.2-1`
- [x] `env-iup`    `v0.2`, rock `0.2-1` (migrated + uploaded per
      its plan; on the `v0.2` branch; only `main` ff was pending.
      `main` itself is stale on `0.1-1` -- verify branch/ff).
- [ ] `env-js`     POSTPONED (v0.6 -> v0.7)

BREAKING: the post-0.7-1 core changes are NOT a re-smoke. Apps
and envs hard-break on 0.7-2 (no `every` alias; `spawn(fn)` now
rejects bare functions; `task()` me-accessor moved to `xtask()`).
Every sibling repo must be migrated + re-released (mirrors the
0.7-1 §4 effort).

Mechanical migration (per repo):
- `every(`  -> `loop_on(`            (120 sites across repos)
- `task()` / `task().f` -> `xtask()` (52 sites)
- `spawn(function...` -> judgment:
    - `do_spawn(function...` if self-contained
    - `spawn(task(function...))` if identity reused (~15 sites)

Per-repo breaking counts (every / spawn(fn)):
env-sdl 3/1, env-pico 4/1, env-socket 1/0, env-iup 4/1,
sdl-birds 34/0, sdl-rocks 15/5, sdl-pingus 6/2, pico-birds 34/0,
pico-rocks 15/5, iup-7guis 3/0. (`task()` accessor extra.)

NOTE: these repos are outside this worktree -- migrate each in
its own checkout/session. Only the 4 `env-*` have a `260618-*`
plan; the apps + iup-7guis are tracked as downstream targets
INSIDE their associated env plan (no own plan file).

Envs (tier A mechanical: every/task()/spawn) -- have plans:
- [ ] env-socket  `260618-release-v0.2.md`   (-> rock 0.2-2)
- [ ] env-sdl     `260618-release-v0.2.md`   (-> rock 0.2-2)
- [ ] env-pico    `260618-release-v0.3.md`   (-> rock 0.3-2)
- [ ] env-iup     `260618-release-v0.2.md`   (-> rock 0.2-2; exs
      already 0.7, only every->loop_on + 1 spawn->do_spawn)

Downstream apps (NO own plan -- migrate/test under their env):
- [ ] sdl-birds / sdl-rocks / sdl-pingus  (v0.5) -- under env-sdl
- [ ] pico-birds / pico-rocks             (v0.6) -- under env-pico
- [ ] iup-7guis  (tier C: multi-arg events -> `loop_on({tag,h})`)
      -- under env-iup

**clock** (atmos built-in):
- [ ] `atmos/env/clock/exs/hello.lua`
- [ ] `atmos/env/clock/exs/hello-rx.lua`

(Per-env release detail from the 0.7-1 cut kept below for
reference -- those boxes reflect the PRIOR cut, already done.)

#### 4.1 env-sdl  (see env-sdl/.claude/plans/06-08-release-v0.2.md)

NOTE: env API became main-body + `quit` (no `open`); custom
matching dropped `__atmos` in favor of `tag='sdl'` table
patterns + `until`. Committed + pushed to `origin/v0.2`.

1. [x] Migrate to v0.7 API (main body + `quit`)
2. [x] Update README
3. [x] Phase 1 tests (local)
4. [x] Create rockspec (`atmos-env-sdl-0.2-1.rockspec`)
5. [x] Make rockspec
6. [x] Phase 2 tests (global)
7. [x] Committed `v0.2` + pushed; `main` ff'd to `v0.2`
8. [x] Create/update version branch `v0.2`, push

Apps: sdl-birds / sdl-rocks / sdl-pingus all DONE at `v0.5`.

#### 4.2 env-pico (DONE at v0.3; env-pico done/06-08-release-v0.3.md)

NOTE: bumped to `v0.3` (not v0.2). `main` ff'd + synced;
rockspec `atmos-env-pico-0.3-1.rockspec`.

1. [x] Migrate to v0.7 API
2. [x] Update README
3. [x] Phase 1 tests (local)
4. [x] Create rockspec (`atmos-env-pico-0.3-1.rockspec`)
5. [x] Make rockspec
6. [x] Phase 2 tests (global)
7. [x] Commit, push main
8. [x] Create/update version branch `v0.3`, push

Apps: pico-birds / pico-rocks DONE at `v0.6`.

#### 4.3 env-socket (DONE at v0.2, rock uploaded, main ff'd)

See env-socket/.claude/plans/06-10-release-v0.2.md.
NOTE: socket events re-keyed to string tag + handle:
`{tag='recv'|'send'|'closed', h=<sock>, v=<data>}`.

1. [x] Migrate to v0.7 API
2. [x] Update README
3. [x] Phase 1 tests (local)
4. [x] Create rockspec (`atmos-env-socket-0.2-1` + `-dev-1`)
5. [x] Make rockspec
6. [x] Phase 2 tests (global)
7. [x] Commit, push, uploaded; `main` ff'd to `v0.2`
8. [x] Create/update version branch `v0.2`, push

#### 4.4 env-iup (DONE at v0.2, rock uploaded, main ff'd)

See env-iup/.claude/plans/06-10-release-v0.2.md.
NOTE: dropped `__atmos` + `.atm` proxy; widget events key on
the IUP handle directly: `{tag='action'|'value'|'close',
h=<handle>, v=<data>}` (iuplua caches one wrapper per widget).
`iup-net.lua` depends on env-socket v0.2.

1. [x] Migrate to v0.7 API
2. [x] Update README
3. [x] Phase 1 tests (local)
4. [x] Create rockspec (`atmos-env-iup-0.2-1`; `-dev-1` exists)
5. [x] Make rockspec
6. [x] Phase 2 tests (global)
7. [x] Commit + push + uploaded; `main` ff'd to `v0.2`
8. [x] Create/update version branch `v0.2`, push

#### 4.5 env-js

1. [ ] Migrate to v0.7 API
2. [ ] Update README (v0.6 -> v0.7)
3. [ ] Update/create build script (`build-v0.7.sh`)
4. [ ] Rebuild HTML files (v0.7)
5. [ ] Test in browser (automated via Puppeteer)
6. [ ] Run automated tests (`cd test && npm ci && npm test`)
7. [ ] Commit, push main
8. [ ] Create version branch, push

### 5. Commit, push main, create release branch

Re-merge the post-0.7-1 work to main for this rev:

- [ ] Push main, check GitHub Actions CI green
- [ ] Update `v0.7` branch, push
- [ ] Return to main

### 6. Publish rockspec to LuaRocks

```bash
luarocks upload atmos-0.7-2.rockspec          # [ ] publish next rev
```

Env rocks unchanged unless an env source changed.
Verify via `luarocks --lua-version=5.4 search atmos`.

### 7. Verify LuaRocks install + test all examples (remote)

Smoke-test the PUBLISHED rocks (not local `make`). Examples
ship AS MODULES, so run them with `-e 'require "<mod>"'` from
ANY dir. Apps have NO rock: run from the repo on its version
branch.

#### 7.0 Prerequisites
- `lua5.4`, `luarocks` (5.4 tree)
- `pico-lua`/`pico-sdl`, `lua-sdl2`, `iuplua` per env
- a graphical display for sdl/pico/iup (or `Xvfb`)

#### 7.1 Clean install of the published rocks
```bash
sudo luarocks --lua-version=5.4 remove atmos --force
sudo luarocks --lua-version=5.4 install atmos 0.7
sudo luarocks --lua-version=5.4 install atmos-env-sdl 0.2
sudo luarocks --lua-version=5.4 install atmos-env-pico 0.3
sudo luarocks --lua-version=5.4 install atmos-env-socket 0.2
sudo luarocks --lua-version=5.4 install atmos-env-iup 0.2
```
Order matters: envs pin `atmos ~> 0.7`, so atmos lands first.

#### 7.2 Phase A -- HEADLESS (no display)
- [ ] clock hello    `lua5.4 -e 'require "atmos.env.clock.exs.hello"'`
- [ ] clock hello-rx `lua5.4 -e 'require "atmos.env.clock.exs.hello-rx"'`
- [ ] socket hello   `lua5.4 -e 'require "atmos.env.socket.exs.hello"'`
- [ ] socket cli-srv `lua5.4 -e 'require "atmos.env.socket.exs.cli-srv"'`

#### 7.3 Phase B -- NEEDS DISPLAY (launch, observe, close)

envs:
- [ ] env-sdl   hello / across / click-drag-cancel
- [ ] env-pico  hello / across / click-drag-cancel
- [ ] env-iup   hello / button-counter / iup-net

apps (NO rock -- checkout the version branch, then run):
- [ ] sdl-birds (v0.5) / sdl-rocks (v0.5) / sdl-pingus (v0.5)
- [ ] pico-birds (v0.6) / pico-rocks (v0.6)

#### 7.4 Gotchas
- SMOKE tests (launch + behaves), judged visually.
- env-sdl needs `DejaVuSans.ttf` in cwd.
- pico uses the `pico-lua` binary, not `lua5.4`.
- env-iup `iup-net` needs atmos-env-socket installed.
- `--force` remove wipes local dev `make`: restore with
  `luarocks make` per repo if you keep developing.
- after app runs, `git checkout main`/`master`.

**env-js**: N/A -- not yet released (§4.5 postponed).

### 8. Announce (manual)

- [ ] Twitter / BlueSky
- [ ] Mailing list
- [ ] Students

### 9. Update original release plan

- [x] Edited `.claude/plans/release.md` -- appended a "Release
      Learnings (added after v0.7)" section (per-env migration,
      env API `quit`, `{tag,h,v}` event idiom, bare-us clock,
      version-branch convention, two-rockspec convention, `main`
      ff reminder, per-env plans, Phase-2 != remote).
