# Plan: Release v0.7

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

- [ ] Automatic tests:

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

- [ ] Add `v0.7` to version list
- [ ] Update stable link from `v0.6` to `v0.7`
- [ ] Update `Install & Run` section: `install atmos 0.7`
- [ ] Update examples for new `await`/`emit`/clock syntax
- [ ] Test examples in the doc

#### 2.2 HISTORY.md

- [x] v0.7 entry drafted (confirm date `jun/26`)

#### 2.3 Rockspec description

- [ ] Keep in sync with README "About" section

#### 2.4 guide.md

- [ ] Update `await`/`emit` to single-arg events
- [ ] Document clock as `dt` microseconds + constants
- [ ] Document `abort`
- [ ] Document `await(ts, 'any'|'all')`
- [ ] Document `toggle` filter
- [ ] Document logical combinators `or`/`and`/`not`
- [ ] Document `__atmos` metamethod

#### 2.5 api.md

- [ ] `emit(v)` / `await(v)` single arg
- [ ] `await(ts, ['any'|'all'])`
- [ ] clock: `dt` microseconds + constants
- [ ] `abort`
- [ ] `toggle(..., [filter], ...)`
- [ ] combinators `{ tag='or'/'and'/'not' }`
- [ ] `__atmos`
- [ ] env API: main body + `quit` (was `open`/`close`)
- [ ] `S.fr_await` (was `S.from(clock)`)

### 3. Rockspec

- [ ] Create `atmos-0.7-1.rockspec`
- [ ] Install locally

### 4. Release all environments and apps

Two test phases for each env/app:
1. **Local**: use `LUA_PATH` trick from README
2. **Global**: `luarocks make` to install, then test

Each env needs the `open`+`close` -> main body + `quit` migration
and any `emit`/`await`/clock syntax updates.

**clock** (atmos built-in):
- [ ] `atmos/env/clock/exs/hello.lua`
- [ ] `atmos/env/clock/exs/hello-rx.lua`

#### 4.1 env-sdl

Env steps:
1. [ ] Migrate to v0.7 API (`open`/`close` -> body + `quit`)
2. [ ] Update README (atmos `v0.7`, env bump)
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

##### 4.1.1 sdl-birds
- [ ] Migrate to v0.7 API
- [ ] Check README.md: app, atmos, env versions
- [ ] Test `birds-11.lua`
- [ ] Commit, push main
- [ ] Create branch, push

##### 4.1.2 sdl-rocks
- [ ] Migrate to v0.7 API
- [ ] Check README.md: app, atmos, env versions
- [ ] Test `main.lua`
- [ ] Commit, push main
- [ ] Create branch, push

##### 4.1.3 sdl-pingus
- [ ] Migrate to v0.7 API
- [ ] Check README.md: app, atmos, env versions
- [ ] Test `main.lua`
- [ ] Commit, push main
- [ ] Create branch, push

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

### 5. Commit, push main, create release branch

- [ ] Push main, check GitHub Actions for green CI
- [ ] Create branch `v0.7`, push
- [ ] Return to main

### 6. Publish all rockspecs to LuaRocks

```bash
luarocks upload atmos-0.7-1.rockspec
luarocks upload atmos-env-sdl-0.2-1.rockspec
luarocks upload atmos-env-pico-0.2-1.rockspec
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
