# Plan: Release v0.7

## RESUME HERE (state @ 2026-06-10)

This (atmos) repo:

- DONE + PUSHED: §1 tests, §2 docs (README, guide, api,
  HISTORY), §3 rockspec `atmos-0.7-1.rockspec` (+ `luarocks
  make`), §4.0 clock examples.
- §5 DONE: `main` released. `origin/main` = `a5fc70e` has
  `v0.7` fully merged + 3 commits; `v0.7` branch pushed.
  Local `main` synced to origin.
- Atmos also gained the `'clock'` await primitive +
  `_us_.._day_` constants (run.lua / init.lua).

Per-env progress lives in EACH env repo's own plan:

- `env-sdl`: DONE (`v0.2`), `main` ff'd, tested. Dependent
  apps DONE + tested: `sdl-birds` v0.5, `sdl-pingus` v0.5,
  `sdl-rocks` v0.5. Only luarocks upload left.
- `env-pico`: DONE at `v0.3` (not v0.2), `main` ff'd, synced.
- `env-socket`: DONE at `v0.2`, rock uploaded, `main` ff'd +
  synced. Events re-keyed to string tag + `h` handle.
- `env-iup`: DONE at `v0.2`, rock uploaded, `main` ff'd +
  synced. Events key on the IUP handle directly (no `__atmos`,
  no `.atm`).
- `env-js`: NOT STARTED.

Next actions, in order:

1. Migrate `env-js` (own plan; Puppeteer build/test, not a
   plain syntax migration -- see §4.5).
2. §6 upload all rockspecs (atmos + sdl + pico). §7 remote
   verify. §9 backport learnings to `release.md`.

## Context

Atmos v0.6 extracted all envs (except clock) to separate repos.
v0.7 is mostly a core/language refactor with breaking changes to
`await`/`emit`, the clock, and the environment API.
This plan uses release branches (not tags) for versioning.

New since v0.6 (see HISTORY.md):

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
    - `break()` inside `every`

## Steps

### 1. Run tests

- [x] Automatic tests: all pass

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

Status (checked 06-08): api.md + HISTORY.md done; guide.md
mostly done with stale calls; README.md only needs version bumps.

#### 2.1 README.md (done)

Examples already use `_s_` (v0.7-clean); only version strings.

- [x] Add `v0.7` to version list (line 11)
- [x] Update stable link from `v0.6` to `v0.7` (line 19)
- [x] Update `Install & Run`: `install atmos 0.7` (line 128)
- [ ] Re-test examples in the doc

#### 2.2 HISTORY.md (done)

- [x] v0.7 entry drafted (confirm date `jun/26`)

#### 2.3 Rockspec description (done)

- [x] Synced `detailed` with README "About": added the
      Functional Streams / Multithreading block (was missing in
      0.6 rockspec). Done in `atmos-0.7-1.rockspec` (see §3).

#### 2.4 guide.md (done)

Already migrated: clock `dt`/`_s_`, `abort`, `toggle`,
`fr_await`. Stale multi-arg calls fixed:

- [x] line 357 `emit('X', false)` -> `emit { tag='X', false }`
- [x] line 359 `emit('X', true)` -> `emit { tag='X', true }`
- [x] line 416 `await('X', id)` -> `await { tag='X', v=id }`
- [x] line 425 `emit('X', 2)` -> `emit { tag='X', v=2 }`
- [x] line 499 `S.from(1)`: kept (f-streams counter; only
      `S.from(clock)` removed; matches `tst/guide.lua:195`)

Note: toggle uses positional `{ tag='X', false }` because the
derived statement awaits `{tag=e, false}` (run.lua:738/740);
trace uses named `v` per the stream idiom.

#### 2.5 api.md (done)

Verified present: single-arg `emit`/`await`,
`{tag='tasks', mode='any'/'all'}`, `dt`/constants, `abort`,
`toggle`, `{tag='or'/'and'/'not'}`, `__atmos`, env `quit`,
`S.fr_await`.

### 3. Rockspec

- [x] Create `atmos-0.7-1.rockspec` (version 0.7-1, branch v0.7,
      `detailed` synced with README)
- [x] Install locally (`luarocks make atmos-0.7-1.rockspec`)

### 4. Release all environments and apps

Two test phases for each env/app:
1. **Local**: use `LUA_PATH` trick from README
2. **Global**: `luarocks make` to install, then test

Each env needs the `open`+`close` -> main body + `quit` migration
and any `emit`/`await`/clock syntax updates.

**clock** (atmos built-in):
- [x] `atmos/env/clock/exs/hello.lua`
- [x] `atmos/env/clock/exs/hello-rx.lua`

#### 4.1 env-sdl  (see env-sdl/.claude/plans/06-08-release-v0.2.md)

NOTE: env API became main-body + `quit` (no `open`); custom
matching dropped `__atmos` in favor of `tag='sdl'` table
patterns + `until`. Committed + pushed to `origin/v0.2`.

1. [x] Migrate to v0.7 API (main body + `quit`)
2. [x] Update README
3. [x] Phase 1 tests (local)
    - [x] `exs/hello.lua`
    - [x] `exs/across.lua`
    - [x] `exs/click-drag-cancel.lua`
4. [x] Create rockspec (`atmos-env-sdl-0.2-1.rockspec`)
5. [x] Make rockspec
6. [x] Phase 2 tests (global)
    - [x] `exs/hello.lua`
    - [x] `exs/across.lua`
    - [x] `exs/click-drag-cancel.lua`
7. [x] Committed `v0.2` + pushed; `main` ff'd to `v0.2`
8. [x] Create/update version branch `v0.2`, push

##### 4.1.1 sdl-birds (DONE, v0.5)
- [x] Migrate to v0.7 API
- [x] Check README.md: app, atmos, env versions
- [x] Test `birds-11.lua` (11 exs)
- [x] Commit, push main
- [x] Create branch, push

##### 4.1.2 sdl-rocks (DONE, v0.5*; *master)
- [x] Migrate to v0.7 API
- [x] Check README.md: app, atmos, env versions
- [x] Test `main.lua`
- [x] Commit, push main
- [x] Create branch, push

##### 4.1.3 sdl-pingus (DONE, v0.5)
- [x] Migrate to v0.7 API
- [x] Check README.md: app, atmos, env versions
- [x] Test `main.lua`
- [x] Commit, push main
- [x] Create branch, push

#### 4.2 env-pico (DONE at v0.3; see env-pico done/06-08-release-v0.3.md)

NOTE: bumped to `v0.3` (not v0.2). `main` ff'd + synced;
rockspec `atmos-env-pico-0.3-1.rockspec`.

Env steps:
1. [x] Migrate to v0.7 API
2. [x] Update README
3. [x] Phase 1 tests (local)
    - [x] `exs/hello.lua`
    - [x] `exs/across.lua`
    - [x] `exs/click-drag-cancel.lua`
4. [x] Create rockspec (`atmos-env-pico-0.3-1.rockspec`)
5. [x] Make rockspec
6. [x] Phase 2 tests (global)
    - [x] `exs/hello.lua`
    - [x] `exs/across.lua`
    - [x] `exs/click-drag-cancel.lua`
7. [x] Commit, push main
8. [x] Create/update version branch `v0.3`, push

##### 4.2.1 pico-birds (DONE)
- [x] Migrate to v0.7 API
- [x] Check README.md: app, atmos, env versions
- [x] Test `birds-11.lua`
- [x] Commit, push main
- [x] Create branch, push

##### 4.2.2 pico-rocks (DONE)
- [x] Migrate to v0.7 API
- [x] Check README.md: app, atmos, env versions
- [x] Test `main.lua`
- [x] Commit, push main
- [x] Create branch, push

#### 4.3 env-socket (DONE at v0.2, rock uploaded, main ff'd)

See env-socket/.claude/plans/06-10-release-v0.2.md.
NOTE: socket events re-keyed to string tag + handle:
`{tag='recv'|'send'|'closed', h=<sock>, v=<data>}`.

Env steps:
1. [x] Migrate to v0.7 API
2. [x] Update README
3. [x] Phase 1 tests (local)
    - [x] `exs/hello.lua`
    - [x] `exs/cli-srv.lua`
4. [x] Create rockspec (`atmos-env-socket-0.2-1` + `-dev-1`)
5. [x] Make rockspec
6. [x] Phase 2 tests (global)
    - [x] `exs/hello.lua`
    - [x] `exs/cli-srv.lua`
7. [x] Commit, push, uploaded; `main` ff'd to `v0.2`
8. [x] Create/update version branch `v0.2`, push

#### 4.4 env-iup (DONE at v0.2, rock uploaded, main ff'd)

See env-iup/.claude/plans/06-10-release-v0.2.md.
NOTE: dropped `__atmos` + `.atm` proxy; widget events key on
the IUP handle directly: `{tag='action'|'value'|'close',
h=<handle>, v=<data>}` (iuplua caches one wrapper per widget).
`iup-net.lua` depends on env-socket v0.2.

Env steps:
1. [x] Migrate to v0.7 API
2. [x] Update README
3. [x] Phase 1 tests (local)
    - [x] `exs/hello.lua`
    - [x] `exs/button-counter.lua`
    - [x] `exs/iup-net.lua`
4. [x] Create rockspec (`atmos-env-iup-0.2-1`; `-dev-1` exists)
5. [x] Make rockspec
6. [x] Phase 2 tests (global)
    - [x] `exs/hello.lua`
    - [x] `exs/button-counter.lua`
    - [x] `exs/iup-net.lua`
7. [x] Commit + push + uploaded; `main` ff'd to `v0.2`
8. [x] Create/update version branch `v0.2`, push

#### 4.5 env-js

1. [ ] Migrate to v0.7 API
2. [ ] Update README (v0.6 -> v0.7)
3. [ ] Update/create build script (`build-v0.7.sh`)
4. [ ] Rebuild HTML files (v0.7)
5. [ ] Test in browser (automated via Puppeteer)
    - [ ] `exs/hello.lua` (bare Lua)
    - [ ] `exs/hello-atmos.lua` (lua-atmos)
    - [ ] `exs/hello.atm` (atmos-lang)
6. [ ] Run automated tests
    - `cd test && npm ci && npm test`
7. [ ] Commit, push main
8. [ ] Create version branch, push

### 5. Commit, push main, create release branch (DONE)

- [x] Push main (`origin/main` = `a5fc70e`, v0.7 merged + 3),
      check GitHub Actions for green CI
- [x] Create branch `v0.7`, push
- [x] Return to main

### 6. Publish all rockspecs to LuaRocks (DONE -- all verified published)

```bash
luarocks upload atmos-0.7-1.rockspec          # [x] published
luarocks upload atmos-env-sdl-0.2-1.rockspec  # [x] published
luarocks upload atmos-env-pico-0.3-1.rockspec # [x] published (0.3, not 0.2)
luarocks upload atmos-env-socket-0.2-1.rockspec # [x] published
luarocks upload atmos-env-iup-0.2-1.rockspec  # [x] published
```

Verified via `luarocks --lua-version=5.4 search <pkg>`.
Apps have NO rockspec (git-only; version branches).

### 7. Verify LuaRocks install + test all examples again (remote)

Installs the PUBLISHED rocks (not local `make`). Each example
is then run from its repo against the global install (NO
LUA_PATH trick) -- that exercises the installed env + atmos.

```bash
# clean install of the published rocks
sudo luarocks --lua-version=5.4 remove atmos --force
sudo luarocks --lua-version=5.4 install atmos 0.7
sudo luarocks --lua-version=5.4 install atmos-env-sdl 0.2
sudo luarocks --lua-version=5.4 install atmos-env-pico 0.3
sudo luarocks --lua-version=5.4 install atmos-env-socket 0.2
sudo luarocks --lua-version=5.4 install atmos-env-iup 0.2
```

Notes:
- sdl / pico / iup examples need a graphical display.
- env-sdl needs `DejaVuSans.ttf` in the cwd.
- env-iup `iup-net.lua` also needs atmos-env-socket installed.
- apps carry NO rockspec: `git checkout <branch>` then run.

**clock** (atmos built-in, run from atmos repo):
- [ ] `lua5.4 atmos/env/clock/exs/hello.lua`
- [ ] `lua5.4 atmos/env/clock/exs/hello-rx.lua`

**env-sdl** (`cd env-sdl`):
- [ ] `lua5.4 exs/hello.lua`
- [ ] `lua5.4 exs/across.lua`
- [ ] `lua5.4 exs/click-drag-cancel.lua`

**sdl-birds** (`cd sdl-birds && git checkout v0.5`):
- [ ] `lua5.4 birds-11.lua`

**sdl-rocks** (`cd sdl-rocks && git checkout v0.5`):
- [ ] `lua5.4 main.lua`

**sdl-pingus** (`cd sdl-pingus && git checkout v0.5`):
- [ ] `lua5.4 main.lua`

**env-pico** (`cd env-pico`):
- [ ] `pico-lua exs/hello.lua`
- [ ] `pico-lua exs/across.lua`
- [ ] `pico-lua exs/click-drag-cancel.lua`

**pico-birds** (`cd pico-birds && git checkout v0.6`):
- [ ] `pico-lua birds-11.lua`

**pico-rocks** (`cd pico-rocks && git checkout v0.6`):
- [ ] `pico-lua main.lua`

**env-socket** (`cd env-socket`):
- [ ] `lua5.4 exs/hello.lua`
- [ ] `lua5.4 exs/cli-srv.lua`

**env-iup** (`cd env-iup`):
- [ ] `lua5.4 exs/hello.lua`
- [ ] `lua5.4 exs/button-counter.lua`
- [ ] `lua5.4 exs/iup-net.lua`

**env-js**: N/A -- env-js not yet released (§4.5 pending);
verify after its release.

### 8. Announce (manual)

- Twitter / BlueSky
- Mailing list
- Students

### 9. Update original release plan

- [x] Edited `.claude/plans/release.md` -- appended a "Release
      Learnings (added after v0.7)" section covering: per-env
      migration step, env API `quit`, `{tag,h,v}` event idiom
      (+ `__atmos`/`.atm` removal), bare-us clock, independent
      version-branch convention, two-rockspec convention,
      `main` ff reminder, per-env plans, Phase-2 != remote.
