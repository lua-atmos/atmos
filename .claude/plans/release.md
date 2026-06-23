# Plan: Release vX.Y (TEMPLATE)

Reusable checklist for a FULL Atmos release: core rock, all
environments, all downstream apps, remote verify, announce.
Copy this file to `.claude/plans/YYMMDD-release-vX.Y.md` and fill
it in per release.
Replace `vX.Y` (atmos), `vN` (per-env branch), `<rev>` (rockspec
rev) throughout.

## Context

Fill in per release:

- What changed since the last cut (additions, modifications,
  removals, bug fixes); mirror this into HISTORY.md.
- Whether this rev ships NEW code or only corrected METADATA
  (see branch-tracking note below).

## §0. Conventions (read first)

These drive every decision below.

### Always `luarocks --lua-version=5.4`

Every `luarocks` invocation (list / show / make / install /
remove / search / upload) MUST pass `--lua-version=5.4`.
Always use and recommend this form -- never a bare `luarocks`.

### Branch-tracking (not tags)

All rocks pin `source.branch` (atmos -> `vX.Y`, envs -> `vN`),
NOT a tag.
So pushing migrated code to a version branch ALREADY serves it
under the EXISTING rock rev.
A new rev (`0.7-2`, `0.3-2`, ...) only re-publishes corrected
METADATA -- it ships no new code.
luarocks.org rejects overwriting a published version, so any
description fix can ONLY ship via a fresh rev.

### Per-env version branches are INDEPENDENT

Each env/app bumps to ITS OWN next unused `vN`, not lockstep
with atmos.
Example cut: env-sdl `v0.2`, env-pico `v0.3`, env-socket `v0.2`,
env-iup `v0.2`; apps `v0.5`/`v0.6`.

### Two rockspecs per env

- `atmos-env-X-<rev>.rockspec`: `source.branch = vN`, pinned dep
  `atmos ~> X.Y`.
- `atmos-env-X-dev-1.rockspec`: `source.branch = main`,
  unversioned `atmos` (single dev spec convention -- remove the
  stale one).

### Per-env plans + master RESUME

Each repo keeps its own `.claude/plans/YYMMDD-release-vN.md`;
mirror the reference env (env-sdl).
The atmos master plan only tracks cross-repo state in a RESUME
block.

### `main` fast-forward (easy to forget)

Develop + commit on the release branch `vN`, push it, THEN ff
`main`:
`git checkout main && git merge --ff-only vN && git push`.
Always verify `main == vN == origin/main` before calling a repo
done.

### All repos checked out on `vN`

Keep every in-scope repo checked out on its `vN` branch (not
`main`/`master`), with `local == remote` and `main` ff'd to `vN`.
Verify per repo: `HEAD == vN`.
Excluded repos (postponed / won't-do / deps) may stay on `main`.

### Cross-project barrier (coordinated releases)

A release may be GATED by work in another project / session
(e.g. the atmos-lang language vs the lua-atmos library share
`vX.Y`). When so, name the BARRIER explicitly before §6 and HOLD
every publish/announce step (§6, §7, §8.1, §9) until it clears,
so the projects ship coordinated. No barrier -> proceed normally.

## §1. Run tests

- [ ] Automatic tests:

```bash
cd tst && lua5.4 all.lua
```

List all tests in the docs.

- [ ] Manual tests (snippets vs `tst/*.lua`):
    - [ ] README.md   -> `tst/readme.lua`
    - [ ] guide.md    -> `tst/guide.lua` (markers `<!-- tst/guide.lua : N.N -->`)

The `.lua` files are the runnable extractions of the doc snippets;
they may use faster timers and add extra coverage. Verify the API
matches and align any drifted print strings (lua follows md).

## §2. Docs

Check ALL docs are consistent before cutting:

- [ ] README.md
- [ ] guide.md
- [ ] api.md
- [ ] HISTORY.md

### 2.0 Scan recent commits for undocumented changes

- [ ] `git log --since=... --stat` since the last cut; cross-check
      each API change against the docs and HISTORY. Watch for
      heading edits that silently break `(#anchor)` links.

### 2.1 README.md

- [ ] Add `vX.Y` to version list
- [ ] Update stable link to `vX.Y`
- [ ] Update `Install & Run`: `install atmos X.Y`
- [ ] Re-check every example against the new API
- [ ] Environments section: bundled (clock) vs separate repos
      (lua-atmos/env-sdl, env-pico, env-socket, env-iup)

### 2.2 HISTORY.md

- [ ] Add the `vX.Y` entry (additions / modifications / removals
      / fixes) -- the source of truth for "what changed".

### 2.3 Rockspec description

- [ ] Keep `detailed` in sync with the README "About" section.
      A stale word here is a metadata-only reason to bump a rev.

### 2.4 guide.md

- [ ] Walk every snippet against the new API.
- [ ] Terminology aligned with api.md.

### 2.5 api.md

- [ ] Final consistency pass vs guide.md (api.md tends to lead).

## §3. Migrate siblings (only if core has BREAKING changes)

A version bump + README edit is NOT enough when the core API
breaks.
Each env/app needs a real MIGRATION before its README step.

### Process per repo (own checkout/session -- outside this tree)

1. Apply the mechanical rewrites (see table below).
2. `luac -p` every touched file.
3. Run the examples.
4. THEN do the per-env release loop (§5).

### Mechanical-migration pitfalls (from the v0.7 cut)

- Spaced calls `every (` / `spawn (` are MISSED by a
  `\bevery\(` sed; match `\s*` before `\(`.
- Wrap a task DEFINITION once, not each call site:
  `function Bird(a)..end` -> `Bird = task(function(a)..end)`
  (preserve scope; keep any `return Bird`). Spawn sites stay
  bare.
- Record per-repo breaking counts in a table so nothing is
  missed:

```
repo         breaking-A   breaking-B   notes
env-sdl      <n>          <n>
sdl-birds    <n>          <n>
...
```

## §4. Rockspec (atmos core)

- [ ] Create `atmos-X.Y-<rev>.rockspec` (copy prior rev, apply
      description fix, keep `source.branch = vX.Y`). Leave the
      prior rev untouched.
- [ ] Create/refresh `atmos-dev-<n>.rockspec` (replaces the old
      dev spec; single dev spec convention).
- [ ] Install locally: `luarocks make atmos-X.Y-<rev>.rockspec`.
      NOTE: this is a LOCAL install, NOT the remote verify (§8).

## §5. Release all environments and apps

Two test phases for each env/app:
1. **Local**: `LUA_PATH` trick from README.
2. **Global**: `luarocks make` to install, then test.

Per-env release loop (8 steps):

1. [ ] Migrate to vX.Y API (only if core broke -- see §3)
2. [ ] Update README (app/atmos/env versions)
3. [ ] Phase 1 tests (local)
4. [ ] Create rockspec(s) (`<rev>` + `dev`)
5. [ ] Make rockspec (global install)
6. [ ] Phase 2 tests (global)
7. [ ] Commit, push `vN`; ff `main` to `vN`
8. [ ] Create/update version branch `vN`, push

Per-env rock-rev DECISION: if branch-tracking already serves the
code fix AND the published `detailed` text is still correct,
SKIP the rev bump (the branch serves it under the existing rev).
Bump ONLY when the published description is wrong.

### Env API evolution (note for the next breaking change)

- v0.6: `open` + `mode` introduced.
- v0.7: `open`+`close` -> main body + optional `quit`.
    - `loop` no longer calls `open`; `stop` calls `env.quit`.
    - `quit` is OPTIONAL (run.lua guards `if env.quit`): omit it
      when the env frees nothing global (e.g. env-socket).
- Event/await idiom (v0.7): single-arg `emit`/`await`, payload
  `{ tag=<selector>, h=<handle>, v=<payload> }`.
    - `tag` STRING selector (readable trace; catch-all
      `await{tag='recv'}`, `M.is` prefix match).
    - `h` source handle, matched by `==` equality.
    - `v` payload. Predicates: `{tag='until'|'while', <pat>, pred}`.
    - IUP: key on the handle directly (`h=but`); iuplua caches one
      wrapper per widget.
- Clock (v0.7): envs emit a BARE NUMBER in microseconds; core
  `'clock'` consumes it. Constants `_us_ _ms_ _s_ _min_ _h_
  _day_`; `clock{s=5}` -> `5 * _s_`; `S.from(clock)` ->
  `S.fr_await(<us>)`.

### Envs (each has its own plan)

- [ ] env-sdl     `vN`
- [ ] env-pico    `vN`
- [ ] env-socket  `vN`
- [ ] env-iup     `vN`
- [ ] env-js      (build script + Puppeteer; see 5.x below)

### Downstream apps (NO own plan -- tracked under their env)

- [ ] sdl-birds / sdl-rocks / sdl-pingus    (under env-sdl)
- [ ] pico-birds / pico-rocks               (under env-pico)
- [ ] iup-7guis                             (under env-iup)

### clock (atmos built-in)

- [ ] `atmos/env/clock/exs/hello.lua`
- [ ] `atmos/env/clock/exs/hello-rx.lua`

### env-js (web build -- own sub-steps)

1. [ ] Migrate to vX.Y API
2. [ ] Update README (prev -> vX.Y)
3. [ ] Update/create build script (`build-vX.Y.sh`)
4. [ ] Rebuild HTML files (vX.Y)
5. [ ] Test in browser (automated via Puppeteer)
6. [ ] Run automated tests (`cd test && npm ci && npm test`)
7. [ ] Commit, push main
8. [ ] Create version branch, push

## ⛔ BARRIER (if any) -- HOLD publish/announce

If a cross-project barrier applies (see §0), NAME it here and do
NOT proceed past this point -- §6 (push / ff main), §7 (publish),
§8.1 (remote verify), §9 (announce) all wait until it clears.
Pre-barrier work (§1-§5 + local verify) may complete freely.

## §6. Commit, push main, create release branch  (⛔ barrier)

- [ ] Push main, check GitHub Actions CI green
- [ ] Create/update branch `vX.Y`, push
- [ ] Return to main (verify `main == vX.Y == origin/main`)
- [ ] Verify EVERY in-scope repo HEAD == `vN` (checked out on the
      version branch), local == remote, main ff'd to `vN`.

## §7. Publish rockspecs to LuaRocks  (⛔ barrier)

Publish ALL rockspecs -- atmos AND every env.
Check what is already on luarocks.org first
(`luarocks --lua-version=5.4 search <rock>`): a NEW version is a
first upload (no bump); re-publishing an existing rev needs a
fresh rev. Do NOT silently skip an env whose new version was
never uploaded.

```bash
luarocks --lua-version=5.4 upload atmos-X.Y-<rev>.rockspec
luarocks --lua-version=5.4 upload atmos-env-sdl-<rev>.rockspec
luarocks --lua-version=5.4 upload atmos-env-pico-<rev>.rockspec
luarocks --lua-version=5.4 upload atmos-env-socket-<rev>.rockspec
luarocks --lua-version=5.4 upload atmos-env-iup-<rev>.rockspec
```

Verify: `luarocks --lua-version=5.4 search atmos`.

## §8. Verify LuaRocks install + test all examples (REMOTE)

Smoke-test the PUBLISHED rocks (NOT local `make`).
Phase-2 "global" (`luarocks make`) is a LOCAL install -- this is
a SEPARATE step against the published rock.
Examples ship AS MODULES: run with `-e 'require "<mod>"'` from
ANY dir.
Apps have NO rock: run from the repo on its version branch.

### 8.0 Prerequisites

- `lua5.4`, `luarocks` (5.4 tree)
- `pico-lua`/`pico-sdl`, `lua-sdl2`, `iuplua` per env
- a graphical display for sdl/pico/iup (or `Xvfb`)

### 8.1 Clean install of the published rocks  (⛔ barrier; needs §7)

```bash
sudo luarocks --lua-version=5.4 remove atmos --force
sudo luarocks --lua-version=5.4 install atmos X.Y
sudo luarocks --lua-version=5.4 install atmos-env-sdl vN
sudo luarocks --lua-version=5.4 install atmos-env-pico vN
sudo luarocks --lua-version=5.4 install atmos-env-socket vN
sudo luarocks --lua-version=5.4 install atmos-env-iup vN
```

Order matters: envs pin `atmos ~> X.Y`, so atmos lands first.

### 8.2 Phase A -- HEADLESS (no display)

- [ ] clock hello    `lua5.4 -e 'require "atmos.env.clock.exs.hello"'`
- [ ] clock hello-rx `lua5.4 -e 'require "atmos.env.clock.exs.hello-rx"'`
- [ ] socket hello   `lua5.4 -e 'require "atmos.env.socket.exs.hello"'`
- [ ] socket cli-srv `lua5.4 -e 'require "atmos.env.socket.exs.cli-srv"'`

### 8.3 Phase B -- NEEDS DISPLAY (launch, observe, close)

envs:
- [ ] env-sdl   hello / across / click-drag-cancel
- [ ] env-pico  hello / across / click-drag-cancel
- [ ] env-iup   hello / button-counter / iup-net

apps (NO rock -- checkout the version branch, then run):
- [ ] sdl-birds / sdl-rocks / sdl-pingus
- [ ] pico-birds / pico-rocks

### 8.4 Gotchas

- SMOKE tests (launch + behaves), judged visually.
- env-sdl needs `DejaVuSans.ttf` in cwd.
- pico uses the `pico-lua` binary, not `lua5.4`.
- env-iup `iup-net` needs atmos-env-socket installed.
- `--force` remove wipes local dev `make`: restore with
  `luarocks make` per repo if you keep developing.
- after app runs, `git checkout main`/`master`.

## §9. Announce (manual)  (⛔ barrier)

- [ ] Twitter / BlueSky
- [ ] Mailing list
- [ ] Students
