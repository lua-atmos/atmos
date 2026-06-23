# Plan: Release v0.7

Fresh instance of `release.md` (TEMPLATE), re-cut @ 2026-06-23.
The prior instance (`done/06-08-release-v0.7.md`) is stale -- all
boxes below are RESET so every step is re-verified from scratch.

## RESUME / prior-cut facts (do NOT lose -- reference only)

PRIOR CUT (frozen): rock `atmos-0.7-1` was published 2026-06-09
from `a5fc70e` (main), with env-sdl `v0.2`, env-pico `v0.3`,
env-socket `v0.2`, env-iup `v0.2`, and the 5 apps. That cut was
NEVER announced. Since 0.7-1 the `v0.7` branch grew breaking
changes (`every`->`loop_on`, `task()`->`xtask()`,
`spawn(fn)`->`do_spawn`, `await(T,...)`, `await(f)` removed,
`par_and/or`->`par_all/any`, streams `S.from`->`S.on`).

BRANCH-TRACKING: all rocks pin `source.branch` (atmos -> `v0.7`,
envs -> `vN`), NOT a tag. Pushing migrated code to a version
branch ALREADY serves it under the EXISTING rock rev. A new rev
(`0.7-2`, ...) only re-publishes corrected METADATA.

## Context

v0.6 extracted all envs (except clock) to separate repos.
v0.7 is a core/language refactor with breaking changes to
`await`/`emit`, the clock, the environment API, and the
`task`/`xtask` distinction.

Per-repo versions for this cut:

```
atmos       v0.7   rock 0.7-2 (desc fix; branch=v0.7)
env-sdl     v0.2   rock 0.2-1 (bump SKIPPED unless desc wrong)
env-pico    v0.3   rock 0.3-1 (bump SKIPPED unless desc wrong)
env-socket  v0.2   rock 0.2-1 (bump SKIPPED unless desc wrong)
env-iup     v0.2   rock 0.2-1 (bump SKIPPED unless desc wrong)
env-js      v0.7   POSTPONED (gated on atmos-lang/atmos v0.7)
sdl apps    v0.5   pico apps v0.6   iup-7guis WON'T DO (tier C)
```

## §0. Conventions

CONVENTION (luarocks): every `luarocks` invocation (list / show /
make / install / remove / search / upload) MUST pass
`--lua-version=5.4`. Always use and recommend this form.

CONVENTION (sync): every in-scope repo stays checked out on its
`vX` branch, with `local == remote` and `main` ff'd to `vX`.

Status @ 2026-06-23 -- 10/10 in-scope converged on `vX`:

```
atmos v0.7   env-socket v0.2   env-sdl v0.2   env-pico v0.3 *
env-iup v0.2   sdl-birds v0.5   sdl-rocks v0.5   sdl-pingus v0.5
pico-birds v0.6   pico-rocks v0.6
```

- `*` env-pico: local `init.lua` dirty (drops `pico.zet`) --
  resolve before the cut.
- atmos `main` is -108 vs `v0.7` (ff `main`->`v0.7` at §6).

WON'T DO -- excluded from the `vX`-checkout sync:

```
env-js      POSTPONED, on main
iup-7guis   tier C WON'T DO; remote stub v0.3, local on main
f-streams   dependency (own cadence); main -1, no local vX
```

## §1. Run tests

- [x] Automatic tests:

```bash
cd tst && lua5.4 all.lua
```

List all tests in the docs.

- [x] Manual tests (snippets vs `tst/*.lua`):
    - [x] README.md   -> `tst/readme.lua`
    - [x] guide.md    -> `tst/guide.lua` (markers `<!-- tst/guide.lua : N.N -->`)

The `.lua` files are the runnable extractions of the doc snippets;
they may use faster timers and add extra coverage. Verify the API
matches and align any drifted print strings (lua follows md).
v0.7: aligned 3 print strings (1.3, 3.2, 3.3); readme.lua §2
(streams parany) has no README counterpart (extra test, kept).

## §2. Docs

Check ALL docs are consistent before cutting:

- [x] README.md
- [x] guide.md
- [x] api.md
- [x] HISTORY.md

### 2.0 Scan recent commits for undocumented changes

- [x] `git log --since=... --stat` since the last cut; cross-check
      each API change against the docs. v0.7 found: api.md `emit`
      was multi-arg (now single `emit(e)`); 3 broken anchors from
      heading edits (`emit`, `emit_in`, `toggle` filter).

### 2.1 README.md

- [x] Add `v0.7` to version list
- [x] Update stable link to `v0.7`
- [x] Update `Install & Run`: `install atmos 0.7`
- [x] Re-check every example against the new API
      (`loop_on`, `spawn`/`do_spawn`, `await(T,...)`)
- [x] Environments section: bundled (clock) vs separate repos
      (lua-atmos/env-sdl, env-pico, env-socket, env-iup)

### 2.2 HISTORY.md

- [x] Confirm the `v0.7` entry is complete (additions /
      modifications / removals / fixes). Recently added:
      `await(T,...)`, `await(f)` removal, single-pred
      `{tag='until'|'while', awt, f}`.

### 2.3 Rockspec description

- [x] `detailed` in sync with README "About". A stale word
      (e.g. `every`) is a metadata-only reason to bump a rev.
      v0.7: `0.7-2` already full sync; synced `dev-3` (was
      missing the streams/threads block). No stale terms.

### 2.4 guide.md

- [x] Walk every snippet against the new API.
- [x] Terminology aligned with api.md (`task`/`xtask`).

### 2.5 api.md

- [x] Final consistency pass vs guide.md (api.md leads).
      Fixed: `emit` single-arg, `toggle` `[filter]`, parall TODO,
      3 anchors. Nits won't-do: `#xtask` in HTML comment.

## §3. Migrate siblings (core BROKE -- required)

A version bump + README edit is NOT enough; each env/app needs a
real MIGRATION before its README step.

### Process per repo (own checkout/session -- outside this tree)

1. Apply the mechanical rewrites (table below).
2. `luac -p` every touched file.
3. Run the examples.
4. THEN do the per-env release loop (§5).

### Mechanical rewrites

- `every(` -> `loop_on(`
    - PITFALL: spaced `every (` / `spawn (` are MISSED by a
      `\bevery\(` sed; match `\s*` before `\(`.
- `task()` / `task().f` -> `xtask()`
- `spawn(function...` -> `do_spawn(function...` if self-contained;
  `spawn(task(function...))` if identity reused.
- `spawn`/`spawn_in` of a NAMED proto: wrap the DEFINITION once,
  not each call site:
  `function Bird(a)..end` -> `Bird = task(function(a)..end)`
  (preserve scope; keep any `return Bird`). Spawn sites stay bare.

### Per-repo breaking counts (every / spawn(fn)) -- re-verify

```
repo         every   spawn(fn)   notes
env-sdl      3       1
env-pico     4       1
env-socket   1       0
env-iup      4       1
sdl-birds    34      0
sdl-rocks    15      5
sdl-pingus   6       2
pico-birds   34      0
pico-rocks   15      5
iup-7guis    3       0           WON'T DO (tier C)
```
(`task()` accessor extra, not counted above.)

## §4. Rockspec (atmos core)

- [ ] Create `atmos-0.7-2.rockspec` (copy 0.7-1, `loop_on` desc
      fix, keep `source.branch = v0.7`). Leave 0.7-1 untouched.
- [ ] Create/refresh `atmos-dev-3.rockspec` (replaces dev-2;
      single dev spec convention).
- [ ] Install locally: `luarocks make atmos-0.7-2.rockspec`.
      NOTE: LOCAL install, NOT the remote verify (§8).

## §5. Release all environments and apps

Two test phases for each env/app:
1. **Local**: `LUA_PATH` trick from README.
2. **Global**: `luarocks make` to install, then test.

Per-env release loop (8 steps):

1. [ ] Migrate to v0.7 API (see §3)
2. [ ] Update README (app/atmos/env versions)
3. [ ] Phase 1 tests (local)
4. [ ] Create rockspec(s) (`<rev>` + `dev`)
5. [ ] Make rockspec (global install)
6. [ ] Phase 2 tests (global)
7. [ ] Commit, push `vN`; ff `main` to `vN`
8. [ ] Create/update version branch `vN`, push

Per-env rock-rev DECISION: if branch-tracking already serves the
code fix AND the published `detailed` text is still correct, SKIP
the rev bump. Bump ONLY when the published description is wrong.

### Env API evolution (reference)

- v0.6: `open` + `mode` introduced.
- v0.7: `open`+`close` -> main body + optional `quit`.
    - `loop` no longer calls `open`; `stop` calls `env.quit`.
    - `quit` is OPTIONAL (run.lua guards `if env.quit`): omit it
      when the env frees nothing global (e.g. env-socket).
- Event/await idiom: single-arg `emit`/`await`, payload
  `{ tag=<selector>, h=<handle>, v=<payload> }`.
    - socket: `{tag='recv'|'send'|'closed', h=<sock>, v=<data>}`.
    - iup: key on the handle directly (`h=but`); iuplua caches
      one wrapper per widget. `{tag='action'|'value'|'close',
      h=<handle>, v=<data>}`.
- Clock: envs emit a BARE NUMBER in microseconds; core `'clock'`
  consumes it. Constants `_us_ _ms_ _s_ _min_ _h_ _day_`;
  `clock{s=5}` -> `5 * _s_`; `S.from(clock)` -> `S.on(<us>)`.

### Envs (each has its own plan)

- [ ] env-sdl     `v0.2`   (done/260618-release-v0.2.md)
- [ ] env-pico    `v0.3`   (done/260618-release-v0.3.md)
- [ ] env-socket  `v0.2`   (done/260618-release-v0.2.md)
- [ ] env-iup     `v0.2`   (done/260618-release-v0.2.md)
- [ ] env-js      `v0.7`   POSTPONED (gated on atmos-lang v0.7)

### Downstream apps (NO own plan -- tracked under their env)

- [ ] sdl-birds / sdl-rocks / sdl-pingus  `v0.5`  (under env-sdl)
- [ ] pico-birds / pico-rocks             `v0.6`  (under env-pico)
- [-] iup-7guis  WON'T DO (tier C: multi-arg events) (under env-iup)

### clock (atmos built-in)

- [ ] `atmos/env/clock/exs/hello.lua`
- [ ] `atmos/env/clock/exs/hello-rx.lua`

### env-js (web build -- own sub-steps) -- POSTPONED

1. [ ] Migrate to v0.7 API
2. [ ] Update README (v0.6 -> v0.7)
3. [ ] Update/create build script (`build-v0.7.sh`)
4. [ ] Rebuild HTML files (v0.7)
5. [ ] Test in browser (automated via Puppeteer)
6. [ ] Run automated tests (`cd test && npm ci && npm test`)
7. [ ] Commit, push main
8. [ ] Create version branch, push

## §6. Commit, push main, create release branch

- [ ] Push main, check GitHub Actions CI green
- [ ] Create/update branch `v0.7`, push
- [ ] Return to main (verify `main == v0.7 == origin/main`)

## §7. Publish rockspecs to LuaRocks

```bash
luarocks upload atmos-0.7-2.rockspec
luarocks upload atmos-env-sdl-0.2-2.rockspec      # only if bumped
luarocks upload atmos-env-pico-0.3-2.rockspec     # only if bumped
luarocks upload atmos-env-socket-0.2-2.rockspec   # only if bumped
luarocks upload atmos-env-iup-0.2-2.rockspec      # only if bumped
```

Env rocks unchanged unless the §5 DECISION resolved to bump.
Verify: `luarocks --lua-version=5.4 search atmos`.

## §8. Verify LuaRocks install + test all examples (REMOTE)

Smoke-test the PUBLISHED rocks (NOT local `make`).
Phase-2 "global" (`luarocks make`) is a LOCAL install -- this is
a SEPARATE step against the published rock.
Examples ship AS MODULES: run with `-e 'require "<mod>"'` from
ANY dir. Apps have NO rock: run from the repo on its version
branch.

### 8.0 Prerequisites

- `lua5.4`, `luarocks` (5.4 tree)
- `pico-lua`/`pico-sdl`, `lua-sdl2`, `iuplua` per env
- a graphical display for sdl/pico/iup (or `Xvfb`)

### 8.1 Clean install of the published rocks

```bash
sudo luarocks --lua-version=5.4 remove atmos --force
sudo luarocks --lua-version=5.4 install atmos 0.7
sudo luarocks --lua-version=5.4 install atmos-env-sdl 0.2
sudo luarocks --lua-version=5.4 install atmos-env-pico 0.3
sudo luarocks --lua-version=5.4 install atmos-env-socket 0.2
sudo luarocks --lua-version=5.4 install atmos-env-iup 0.2
```

Order matters: envs pin `atmos ~> 0.7`, so atmos lands first.

### 8.2 Phase A -- HEADLESS (no display)

- [x] clock hello    `lua5.4 -e 'require "atmos.env.clock.exs.hello"'`
- [x] clock hello-rx `lua5.4 -e 'require "atmos.env.clock.exs.hello-rx"'`
- [x] socket hello   `lua5.4 -e 'require "atmos.env.socket.exs.hello"'`
- [x] socket cli-srv `lua5.4 -e 'require "atmos.env.socket.exs.cli-srv"'`

### 8.3 Phase B -- NEEDS DISPLAY (launch, observe, close)

envs:
- [ ] env-sdl   hello / across / click-drag-cancel
- [ ] env-pico  hello / across / click-drag-cancel
- [ ] env-iup   hello / button-counter / iup-net

apps (NO rock -- checkout the version branch, then run):
- [ ] sdl-birds (v0.5) / sdl-rocks (v0.5) / sdl-pingus (v0.5)
- [ ] pico-birds (v0.6) / pico-rocks (v0.6)

### 8.4 Gotchas

- SMOKE tests (launch + behaves), judged visually.
- env-sdl needs `DejaVuSans.ttf` in cwd.
- pico uses the `pico-lua` binary, not `lua5.4`.
- env-iup `iup-net` needs atmos-env-socket installed.
- `--force` remove wipes local dev `make`: restore with
  `luarocks make` per repo if you keep developing.
- after app runs, `git checkout main`/`master`.

**env-js**: N/A -- not yet released (§5 postponed).

## §9. Announce (manual)

- [ ] Twitter / BlueSky
- [ ] Mailing list
- [ ] Students
