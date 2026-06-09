# Plan: Release v0.7

## RESUME HERE (re-checked by source content @ 2026-06-08)

Verified by scanning working trees (commit labels are app
versions and were misleading), not by plan checkboxes.

DONE (v0.7-clean source):

- atmos core: §1-§4.0, §2 docs, §3 rockspec. §5 released to
  `main` (confirmed final; `main` tip == `origin/v0.7` tip).
- SDL family fully migrated + pushed:
    - `env-sdl` (on `main`, `origin/main`==`origin/v0.2`)
    - `sdl-birds`, `sdl-rocks`, `sdl-pingus`

NOT DONE (still have `clock{`, `M.open/close`, multi-arg):

- `env-pico` (next), then `env-socket`, `env-iup`, `env-js`
- `pico-birds`, `pico-rocks` (blocked on `env-pico`)
- §6 LuaRocks uploads: NOT YET (confirmed by user)
- §7 remote verify, §9 backport to `release.md`: pending

Next actions, in order:

1. Migrate `env-pico` -> release as `v0.3` (v0.2 already
   released for pico-sdl v0.5). Plan:
   `env-pico/.claude/plans/06-08-release-v0.3.md`.
2. Then `pico-birds` + `pico-rocks` (depend on env-pico).
3. Migrate `env-socket` -> `env-iup` -> `env-js`.
4. §6 upload all rockspecs to LuaRocks.
5. §7 remote verify. §9 backport learnings to `release.md`.

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

REQUIREMENT (all envs): every `env-*/README.md` must indicate its
CURRENT version (a version list + stable link, like the atmos
README; or a version table like env-js). Today most env READMEs
show only a bare `luarocks install ...` line with no version.

- [x] `env-sdl`    README shows current version (`v0.2`)
- [ ] `env-pico`   README shows current version (`v0.3`)
- [ ] `env-socket` README shows current version (verify number)
- [ ] `env-iup`    README shows current version (verify number)
- [ ] `env-js`     README version table updated (`v0.6` -> `v0.7`)

**clock** (atmos built-in):
- [x] `atmos/env/clock/exs/hello.lua`
- [x] `atmos/env/clock/exs/hello-rx.lua`

#### 4.1 env-sdl  (see env-sdl/.claude/plans/06-08-release-v0.2.md)

NOTE: env API became main-body + `quit` (no `open`); custom
matching dropped `__atmos` in favor of `tag='sdl'` table
patterns + `until`. Committed + pushed to `origin/v0.2`.

1. [x] Migrate to v0.7 API (main body + `quit`)
2. [x] Update README (+ version list: v0.2 stable)
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
7. [x] Committed + pushed; `origin/main`==`origin/v0.2`
8. [x] Create/update version branch `v0.2`, push

##### 4.1.1 sdl-birds  (source v0.7-clean, pushed)
- [x] Migrate to v0.7 API (no old patterns in source)
- [x] Commit, push; version branch present
- [ ] Re-confirm README versions (not re-verified)

##### 4.1.2 sdl-rocks  (source v0.7-clean, pushed)
- [x] Migrate to v0.7 API (no old patterns in source)
- [x] Commit, push; version branch present
- [ ] Re-confirm README versions (not re-verified)

##### 4.1.3 sdl-pingus  (source v0.7-clean, pushed)
- [x] Migrate to v0.7 API (no old patterns in source)
- [x] Commit, push; version branch present
- [ ] Re-confirm README versions (not re-verified)

#### 4.2 env-pico

Env steps:
1. [ ] Migrate to v0.7 API
2. [ ] Update README
3. [ ] Phase 1 tests (local)
    - [ ] `exs/hello.lua`
    - [ ] `exs/across.lua`
    - [ ] `exs/click-drag-cancel.lua`
4. [ ] Create rockspec
5. [ ] Make rockspec
6. [ ] Phase 2 tests (global)
    - [ ] `exs/hello.lua`
    - [ ] `exs/across.lua`
    - [ ] `exs/click-drag-cancel.lua`
7. [ ] Commit, push main
8. [ ] Create/update version branch, push

##### 4.2.1 pico-birds
- [ ] Migrate to v0.7 API
- [ ] Check README.md: app, atmos, env versions
- [ ] Test `birds-11.lua`
- [ ] Commit, push main
- [ ] Create branch, push

##### 4.2.2 pico-rocks
- [ ] Migrate to v0.7 API
- [ ] Check README.md: app, atmos, env versions
- [ ] Test `main.lua`
- [ ] Commit, push main
- [ ] Create branch, push

#### 4.3 env-socket

Env steps:
1. [ ] Migrate to v0.7 API
2. [ ] Update README
3. [ ] Phase 1 tests (local)
    - [ ] `exs/hello.lua`
    - [ ] `exs/cli-srv.lua`
4. [ ] Create rockspec
5. [ ] Make rockspec
6. [ ] Phase 2 tests (global)
    - [ ] `exs/hello.lua`
    - [ ] `exs/cli-srv.lua`
7. [ ] Commit, push main
8. [ ] Create/update version branch, push

#### 4.4 env-iup

Env steps:
1. [ ] Migrate to v0.7 API
2. [ ] Update README
3. [ ] Phase 1 tests (local)
    - [ ] `exs/hello.lua`
    - [ ] `exs/button-counter.lua`
    - [ ] `exs/iup-net.lua`
4. [ ] Create rockspec
5. [ ] Make rockspec
6. [ ] Phase 2 tests (global)
    - [ ] `exs/hello.lua`
    - [ ] `exs/button-counter.lua`
    - [ ] `exs/iup-net.lua`
7. [ ] Commit, push main
8. [ ] Create/update version branch, push

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

### 5. Commit, push main, create release branch (done)

- [x] Push main (main tip == origin/v0.7 tip; confirmed final)
- [x] Create branch `v0.7`, push
- [x] Return to main

### 6. Publish all rockspecs to LuaRocks

```bash
luarocks upload atmos-0.7-1.rockspec
luarocks upload atmos-env-sdl-0.2-1.rockspec
luarocks upload atmos-env-pico-0.3-1.rockspec
luarocks upload atmos-env-socket-0.2-1.rockspec
luarocks upload atmos-env-iup-0.2-1.rockspec
```

### 7. Verify LuaRocks install + test all examples again (remote)

```bash
sudo luarocks --lua-version=5.4 remove atmos
sudo luarocks --lua-version=5.4 install atmos 0.7
```

**clock** (atmos built-in):
- [ ] `atmos/env/clock/exs/hello.lua`
- [ ] `atmos/env/clock/exs/hello-rx.lua`

**env-sdl**:
- [ ] `exs/hello.lua`
- [ ] `exs/across.lua`
- [ ] `exs/click-drag-cancel.lua`

**sdl-birds**:
- [ ] `birds-11.lua`

**sdl-rocks**:
- [ ] `main.lua`

**sdl-pingus**:
- [ ] `main.lua`

**env-pico**:
- [ ] `exs/hello.lua`
- [ ] `exs/across.lua`
- [ ] `exs/click-drag-cancel.lua`

**pico-birds**:
- [ ] `birds-11.lua`

**pico-rocks**:
- [ ] `main.lua`

**env-socket**:
- [ ] `exs/hello.lua`
- [ ] `exs/cli-srv.lua`

**env-iup**:
- [ ] `exs/hello.lua`
- [ ] `exs/button-counter.lua`
- [ ] `exs/iup-net.lua`

**env-js** (automated via Puppeteer):
- [ ] `exs/hello.lua`
- [ ] `exs/hello-atmos.lua`
- [ ] `exs/hello.atm`

### 8. Announce (manual)

- Twitter / BlueSky
- Mailing list
- Students

### 9. Update original release plan

- [ ] Edit `.claude/plans/release.md` at the end with anything
      relevant learned during the v0.7 release, so it stays a
      useful template for future releases. Candidates:
    - New/changed steps (e.g. env API migration, syntax migration)
    - Version-branch naming conventions
    - Per-env rockspec bump conventions
    - Any gotchas found during this release
