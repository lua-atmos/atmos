# Plan: Release v0.6

## Context

Atmos v0.5 bundled 5 environments. For v0.6, envs (except clock)
are extracted to separate repos. New features since v0.5 include
thread cancel, thread no-args, and the env extraction itself.
This plan uses release branches (not tags) for versioning.

## Pending from extract-envs

- [ ] Rockspecs for extracted envs must install into `atmos/env/*`
    - env-iup

## Steps

### 1. Run tests

- [x] Automatic tests:

```bash
cd tst && lua5.4 all.lua
```

List all tests in the docs.

- Manual tests:
    - [x] README.md
    - [x] guide.md

### 2. Docs

- [x] Check if all docs are consistent:

- README.md
- guide.md
- api.md
- HISTORY.md

#### 2.1 README.md (done)

- [x] Add `v0.6` to version list
- [x] Update stable link from `v0.5` to `v0.6`
- [x] Update `Install & Run` section: `install atmos 0.6`
- [x] Remove bundled env directory tree (only clock remains)
- [x] Update Environments section:
    - clock stays as bundled
    - sdl, pico, socket, iup → link to separate repos
      (lua-atmos/env-sdl, env-pico, env-socket, env-iup)
- [x] Test examples in the doc
    - [x] Task-based Hello World (watching/every with clock)
    - [x] Stream-based Hello World — removed from README

#### 2.2 HISTORY.md (done)

- [x] v0.6 entry added

#### 2.3 Rockspec description (done)

- [x] Keep in sync with README "About" section

#### 2.4 guide.md (done)

- [x] Document `thread` block (CPU parallelism via LuaLanes)
    - include implicit abortion

#### 2.5 api.md (done)

- [x] Document `thread(f)` API
- [x] Rename `call` → `loop`
- [x] Fix `atmos.env`: remove `loop`/`stop`, add `open`/`mode`

### 3. Rockspec (done)

- [x] `atmos-0.6-2.rockspec` verified complete
- [x] Installed locally

### 4. Release all environments and apps

Two test phases for each env/app:
1. **Local**: use `LUA_PATH` trick from README
2. **Global**: `luarocks make` to install, then test

**clock** (atmos built-in):
- [x] `atmos/env/clock/exs/hello.lua`
- [x] `atmos/env/clock/exs/hello-rx.lua`

#### 4.1 env-sdl

Env steps:
1. [x] Update README
2. [x] Phase 1 tests (local)
    - [x] `exs/hello.lua`
    - [x] `exs/across.lua`
    - [x] `exs/click-drag-cancel.lua`
3. [x] Create rockspec
4. [x] Make rockspec
5. [x] Phase 2 tests (global)
    - [x] `exs/hello.lua`
    - [x] `exs/across.lua`
    - [x] `exs/click-drag-cancel.lua`
6. [x] Commit, push main
7. [x] Create/update branch `v0.1`, push

##### 4.1.1 sdl-birds
- [x] Check README.md: app, atmos, env versions
- [x] Test `birds-11.lua`
- [x] Commit, push main
- [x] Create branch, push

##### 4.1.2 sdl-rocks
- [x] Check README.md: app, atmos, env versions
- [x] Test `main.lua`
- [x] Commit, push main
- [x] Create branch, push

##### 4.1.3 sdl-pingus
- [x] Check README.md: app, atmos, env versions
- [x] Test `main.lua`
- [x] Commit, push main
- [x] Create branch, push

#### 4.2 env-pico

Note: requires pico-sdl v0.3

Env steps:
1. [x] Update README
2. [x] Phase 1 tests (local)
    - [x] `exs/hello.lua`
    - [x] `exs/across.lua`
    - [x] `exs/click-drag-cancel.lua`
3. [x] Create rockspec
4. [x] Make rockspec
5. [x] Phase 2 tests (global)
    - [x] `exs/hello.lua`
    - [x] `exs/across.lua`
    - [x] `exs/click-drag-cancel.lua`
6. [x] Commit, push main
7. [x] Create/update branch `v0.1`, push

##### 4.2.1 pico-birds
- [x] Check README.md: app, atmos, env versions
- [x] Test `birds-11.lua`
- [x] Commit, push main
- [x] Create branch `v0.4`, push

##### 4.2.2 pico-rocks
- [x] Check README.md: app, atmos, env versions
- [x] Test `main.lua`
- [x] Commit, push main
- [x] Create branch, push

#### 4.3 env-socket

Env steps:
1. [ ] Update README
2. [ ] Phase 1 tests (local)
    - [ ] `exs/hello.lua`
    - [ ] `exs/cli-srv.lua`
3. [ ] Create rockspec
4. [ ] Make rockspec
5. [ ] Phase 2 tests (global)
    - [ ] `exs/hello.lua`
    - [ ] `exs/cli-srv.lua`
6. [ ] Commit, push main
7. [ ] Create/update branch `v0.1`, push

##### 4.3.1 iup-7guis (also needs env-iup)
- [ ] Check README.md: app, atmos, env versions
- [ ] `01-counter.lua`
- [ ] `02-temperature.lua`
- [ ] `03-flight.lua`
- [ ] `01-counter-net.lua`

#### 4.4 env-iup (skipped — extraction not complete)

#### 4.5 env-js (skipped)

### 5. Commit, push main, create release branch

- [ ] Single commit: `release: v0.6`
- [ ] Push main, check GitHub Actions for green CI
- [ ] Create branch `v0.6`
- [ ] Update README links: `main` → `v0.6`
- [ ] Commit and push `v0.6`
- [ ] Return to main

### 6. Publish all rockspecs to LuaRocks (done)

```bash
luarocks upload atmos-0.6-1.rockspec
luarocks upload atmos-env-sdl-0.1-1.rockspec
luarocks upload atmos-env-pico-0.1-1.rockspec
luarocks upload atmos-env-socket-0.1-1.rockspec
```

### 7. Verify LuaRocks install + test all examples again (remote)

```bash
sudo luarocks --lua-version=5.4 remove atmos
sudo luarocks --lua-version=5.4 install atmos 0.6
```

Re-run the same test checklist from step 4 with the remote install.

### 8. Announce (manual)

- Twitter / BlueSky
- Mailing list
- Students
