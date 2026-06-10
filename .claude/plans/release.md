# Plan: Release v0.6

## Context

Atmos v0.5 bundled 5 environments. For v0.6, envs (except clock)
are extracted to separate repos. New features since v0.5 include
thread cancel, thread no-args, and the env extraction itself.
This plan uses release branches (not tags) for versioning.

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

#### 4.4 env-iup

Env steps:
1. [x] Update README
2. [ ] Phase 1 tests (local)
    - [x] `exs/hello.lua`
    - [x] `exs/button-counter.lua`
    - [ ] `exs/iup-net.lua`
3. [x] Create rockspec
4. [x] Make rockspec
5. [ ] Phase 2 tests (global)
    - [x] `exs/hello.lua`
    - [x] `exs/button-counter.lua`
    - [ ] `exs/iup-net.lua`
6. [x] Commit, push main
7. [x] Create/update branch `v0.1`, push

#### 4.5 env-js

1. [x] Update README (v0.5 → v0.6)
2. [x] Update/create build script (`build-v0.6.sh`)
3. [x] Rebuild HTML files (v0.6)
4. [x] Test in browser (automated via Puppeteer)
    - [x] `exs/hello.lua` (bare Lua)
    - [x] `exs/hello-atmos.lua` (lua-atmos)
    - [x] `exs/hello.atm` (atmos-lang)
5. [x] Run automated tests
    - `cd test && npm ci && npm test`
    - Tests both `out/main/` and `out/v0.6/` tiers
6. [x] Commit, push main
7. [x] Create branch `v0.1`, push

### 5. Commit, push main, create release branch (done)

- [x] Push main, check GitHub Actions for green CI
- [x] Create branch `v0.6`, push
- [x] Return to main

### 6. Publish all rockspecs to LuaRocks (done)

```bash
luarocks upload atmos-0.6-1.rockspec
luarocks upload atmos-env-sdl-0.1-1.rockspec
luarocks upload atmos-env-pico-0.1-1.rockspec
luarocks upload atmos-env-socket-0.1-1.rockspec
luarocks upload atmos-env-iup-0.1-1.rockspec
```

### 7. Verify LuaRocks install + test all examples again (remote)

```bash
sudo luarocks --lua-version=5.4 remove atmos
sudo luarocks --lua-version=5.4 install atmos 0.6
```

**clock** (atmos built-in):
- [x] `atmos/env/clock/exs/hello.lua`
- [x] `atmos/env/clock/exs/hello-rx.lua`

**env-sdl**:
- [x] `exs/hello.lua`
- [x] `exs/across.lua`
- [ ] `exs/click-drag-cancel.lua`

**sdl-birds** (`git checkout v0.4`):
- [x] `birds-11.lua`

**sdl-rocks** (`git checkout v0.4`):
- [x] `main.lua`

**sdl-pingus** (`git checkout v0.4`):
- [ ] `main.lua`

**env-pico**:
- [x] `exs/hello.lua`
- [x] `exs/across.lua`
- [x] `exs/click-drag-cancel.lua`

**pico-birds** (`git checkout v0.4`):
- [x] `birds-11.lua`

**pico-rocks** (master, no version branch):
- [x] `main.lua`

**env-socket**:
- [x] `exs/hello.lua`
- [x] `exs/cli-srv.lua`

**env-iup**:
- [x] `exs/hello.lua`
- [x] `exs/button-counter.lua`
- [ ] `exs/iup-net.lua`

**env-js** (automated via Puppeteer):
- [x] `exs/hello.lua`
- [x] `exs/hello-atmos.lua`
- [x] `exs/hello.atm`

### 8. Announce (manual)

- Twitter / BlueSky
- Mailing list
- Students

-------------------------------------------------------------------------------

## Release Learnings (added after v0.7)

Reusable conventions surfaced during the v0.7 release. Apply
these to future releases; they extend the steps above.

### When core has breaking changes, each env needs a MIGRATION

A version bump + README edit is not enough. Insert a
"Migrate to vX API" step (init.lua + examples) BEFORE the
README step, per env. v0.7 broke the env API, the event
syntax, and the clock all at once.

### Env API evolution

- v0.6: `open` + `mode` introduced.
- v0.7: `open`+`close` -> main body + optional `quit`.
    - `loop` no longer calls `open`; `stop` calls `env.quit`.
    - `quit` is OPTIONAL (run.lua guards `if env.quit`): omit
      it when the env frees nothing global (e.g. env-socket).

### Event / await syntax (v0.7): single-arg + `{tag, h, v}`

- `emit`/`await` take ONE arg. Multi-arg `emit(x,'e',v)` ->
  a single table.
- Established idiom: `{ tag=<selector>, h=<handle>, v=<payload> }`
    - `tag` is a STRING selector (readable trace; enables a
      catch-all `await{tag='recv'}` and `M.is` prefix match).
    - `h` is the source handle, matched by `==` equality
      (socket userdata; IUP widget handle).
    - `v` carries the payload.
- Custom matching removed: the `__atmos` metamethod is gone.
  Use core table patterns matched field-by-field
  (run.lua:617-630), plus `{tag='until'|'while', <pat>, pred}`
  for predicates.
- IUP gotcha: key on the handle DIRECTLY (`h=but`). iuplua
  caches one Lua wrapper per widget, so the callback `self`
  equals the user's handle -- no `.atm` proxy needed.

### Clock (v0.7)

- Envs emit a BARE NUMBER in microseconds; the core `'clock'`
  await primitive consumes it (no `'clock'` tag, no `clock{}`).
- Examples use constants `_us_ _ms_ _s_ _min_ _h_ _day_`:
  `clock{s=5}` -> `5 * _s_`. Stream: `S.from(clock)` ->
  `S.fr_await(<us>)`.

### Version-branch convention (per-env, INDEPENDENT)

Each env/app bumps to ITS OWN next version, not lockstep with
atmos. v0.7 cut: env-sdl `v0.2`, env-pico `v0.3` (already had
a `v0.2`), env-socket `v0.2`, env-iup `v0.2`; apps sdl-* and
pico-birds `v0.5`. Rule: next unused `vN` for that repo.

### Rockspec convention (two per env)

- `atmos-env-X-<ver>-1.rockspec`: `source.branch = vN`,
  pinned dep `atmos ~> 0.7`.
- `atmos-env-X-dev-1.rockspec`: `source.branch = main`,
  unversioned `atmos`.

### `main` fast-forward (easy to forget)

Develop + commit on the release branch `vN`, push it, THEN ff
`main`:
`git checkout main && git merge --ff-only vN && git push`.
Always verify `main == vN == origin/main` before calling a
repo done.

### Per-env plans + master RESUME

Each repo keeps its own `.claude/plans/MM-DD-release-vN.md`;
mirror the reference env (env-sdl). The atmos master plan only
tracks cross-repo state in a RESUME block.

### Gotcha: "global" Phase-2 != remote

Phase-2 via `luarocks make` is a LOCAL install. §7 remote
verify (`luarocks install <pkg> <ver>`) against the published
rock is a SEPARATE step -- do not assume Phase-2 covers it.
