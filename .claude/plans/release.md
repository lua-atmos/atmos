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

```bash
cd tst && lua5.4 all.lua
```

### 2. Create rockspec `atmos-0.6-1.rockspec`

- Copy from `atmos-0.5-1.rockspec`
- Change `version` to `"0.6-1"`
- Change `branch` to `"v0.6"`
- Remove all non-clock env modules (sdl, pico, socket, iup)
- Move old rockspec to `old/`
- Install locally:

```bash
sudo luarocks make atmos-0.6-1.rockspec --lua-version=5.4
```

### 3. Release all environments and apps

Two test phases for each env/app:
1. **Local**: use `LUA_PATH` trick from README
2. **Global**: `luarocks make` to install, then test

**clock** (atmos built-in):
- [x] `atmos/env/clock/exs/hello.lua`
- [x] `atmos/env/clock/exs/hello-rx.lua`

#### 3.1 env-sdl

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

##### 3.1.1 sdl-birds
- [x] Test `birds-11.lua` (local)
- [x] Test `birds-11.lua` (global)
- [x] Commit, push main
- [x] Create branch, push

##### 3.1.2 sdl-rocks
- [x] Test `main.lua` (local)
- [x] Test `main.lua` (global)
- [x] Commit, push main
- [x] Create branch, push

##### 3.1.3 sdl-pingus
- [x] Test `main.lua` (local)
- [x] Test `main.lua` (global)
- [x] Commit, push main
- [x] Create branch, push

#### 3.2 env-pico

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
6. [x] Commit (init-on-require), push main
7. [x] Create/update branch `v0.1`, push

##### 3.2.1 pico-birds
- [x] Test `birds-11.lua` (local)
- [x] Test `birds-11.lua` (global)
- [x] Commit, push main
- [x] Create branch `v0.4`, push

##### 3.2.2 pico-rocks
- [x] Test `main.lua` (local)
- [x] Test `main.lua` (global)
- [x] Commit, push main
- [x] Create branch, push

#### 3.3 env-socket

Env steps:
1. [x] Update README
2. [x] Phase 1 tests (local)
    - [x] `exs/hello.lua`
    - [x] `exs/cli-srv.lua`
3. [x] Create rockspec
4. [x] Make rockspec
5. [x] Phase 2 tests (global)
    - [x] `exs/hello.lua`
    - [x] `exs/cli-srv.lua`
6. [x] Commit, push main
7. [x] Create/update branch `v0.1`, push

##### 3.3.1 iup-7guis (also needs env-iup)
- [ ] `01-counter.lua`
- [ ] `02-temperature.lua`
- [ ] `03-flight.lua`
- [ ] `01-counter-net.lua`

#### 3.4 env-iup (skipped — extraction not complete)

#### 3.5 env-js (skipped)

### 4. Update `README.md`

- Add `v0.6` to version list
- Update stable link from `v0.5` to `v0.6`
- Update `Install & Run` section: `install atmos 0.6`
- Remove bundled env directory tree (only clock remains)
- Update Environments section:
    - clock stays as bundled
    - sdl, pico, socket, iup → link to separate repos
      (lua-atmos/env-sdl, env-pico, env-socket, env-iup)

### 5. Update `HISTORY.md`

```
v0.6 (mar/26)
-------------

- Extracted environments to separate repos:
    - env-sdl, env-pico, env-socket, env-iup
- Thread cancel
- Thread no-args
```

### 6. Commit, push main, create release branch

- Single commit: `release: v0.6`
- Push main, check GitHub Actions for green CI
- Create branch `v0.6`
- Update README links: `main` → `v0.6`
- Commit and push `v0.6`
- Return to main

### 7. Publish all rockspecs to LuaRocks

```bash
luarocks upload atmos-0.6-1.rockspec
luarocks upload atmos-env-sdl-0.1-1.rockspec
luarocks upload atmos-env-pico-0.1-1.rockspec
luarocks upload atmos-env-socket-0.1-1.rockspec
```

### 8. Verify LuaRocks install + test all examples again (remote)

```bash
sudo luarocks --lua-version=5.4 remove atmos
sudo luarocks --lua-version=5.4 install atmos 0.6
```

Re-run the same test checklist from step 3 with the remote install.

### 9. Announce (manual)

- Twitter / BlueSky
- Mailing list
- Students
