# Plan: Release v0.8

Instance of `release.md` (TEMPLATE), cut @ 2026-08-15.

## ⚠ GATES (resolve before §1)

- [x] `loop_on`/`_break_` removal DEFERRED to v0.9
      (plan `260627-loop-on-break.md` stays pending;
      HISTORY.md v0.8 draft fixed -- removal line dropped).
- [ ] Decide cross-project BARRIER: does atmos-lang v0.8
      (separate session) gate publish/announce again?

## Context

v0.8 since the v0.7 cut (2026-06-23, ~25 commits on main;
mirror into HISTORY.md -- draft entry already present):

- Additions:
    - `await` pattern `{ tag='spawn', T, ... }`
- Modifications (behavioral):
    - `await :any/all`: awake requires non-empty pool;
      no longer buffered (requires previous await)
    - target emit: skip transparent tasks
- Fixes:
    - `X.gte`: don't recurse into tasks
    - `await T(nil,...)`: handle `nil` arguments
    - clear terminated task / clear empty awake

This rev ships NEW code -> new branch `v0.8` + rock `0.8-1`.

Per-repo versions for this cut (each env bumps its OWN next vN):

```
atmos       v0.8   rock 0.8-1 (first upload; branch=v0.8)
env-sdl     v0.3   rock 0.3-1
env-pico    v0.4   rock 0.4-1
env-socket  v0.3   rock 0.3-1
env-iup     v0.3   rock 0.3-1
env-js      ???    (postponed in v0.7; re-decide)
sdl apps    v0.6   pico apps v0.7   iup-7guis WON'T DO (tier C)
```

## §0. Conventions

- Every `luarocks` invocation MUST pass `--lua-version=5.4`.
- Rocks pin `source.branch` (atmos -> `v0.8`, envs -> `vN`),
  NOT a tag; a new rev only re-publishes metadata.
- Two rockspecs per repo: `<ver>-<rev>` (branch=vN, dep
  `atmos ~> 0.8`) + single `dev` spec (branch=main).
- Every in-scope repo checked out on `vN`, local == remote,
  `main` ff'd to `vN` (`git merge --ff-only vN`).
- Per-env plans in each repo; this master plan tracks
  cross-repo state in a RESUME block.

## RESUME (cross-repo state)

Envs worked FROM THIS SESSION (user-authorized, 2026-08-15).

```
atmos       v0.8 branched, docs+specs done, make+tests OK
            (sudo make 0.8-1 + tst all/readme/guide vs
            installed rock, 2026-08-17)
env-sdl     v0.3 DONE (2026-08-17): audit clean, README+spec,
            phase-1+2 green, 0.3-1 installed, v0.3 pushed,
            main ff'd; ONLY §7 upload left (after atmos)
env-pico    v0.4 branched; audit clean, README+spec done,
            phase-1 green; PENDING sudo make + phase-2
            ⛔ text.dyn fix kept -> pins pico-sdl ~> 0.7;
            pico-sdl 0.7 ships TOGETHER (user) -- publish
            of 0.4-1 gated on pico-sdl 0.7 upload
env-socket  v0.3 branched; audit clean, README+spec done,
            phase-1 green; PENDING sudo make + phase-2
env-iup     v0.3 branched; audit clean, README+spec done,
            phase-1 green; PENDING sudo make + phase-2
env-js      WON'T DO (user)
sdl apps    v0.6 DONE (2026-08-17): birds/rocks/pingus pushed,
            main/master ff'd to v0.6
pico apps   v0.7 branched, README bumped, smoked;
            uncommitted pico-sdl-0.7 API migrations ride along
```

## §1. Run tests

- [x] Automatic tests (2026-08-15, all green):

```bash
cd tst && LUA_PATH="../?.lua;../?/init.lua;;" lua5.4 all.lua
```

NOTE: LUA_PATH trick REQUIRED -- bare `lua5.4 all.lua` picks the
INSTALLED rock (errors.lua exec subprocess trace mismatch).

- [x] `tst/readme.lua` + `tst/guide.lua` run green (same trick)
- [x] Manual tests (snippets vs `tst/*.lua` -- diffed md vs lua):
    - [x] README.md   -> `tst/readme.lua` (hello verbatim;
          lua §2 streams = known extra, kept)
    - [x] guide.md    -> `tst/guide.lua` (all 21 markers match;
          only faster-timer drift, e.g. 4.1 "100 ms elapses";
          1.2/5.2 markers each cover two md snippets)

App smoke @ 2026-08-15 (local v0.8 core via LUA_PATH, installed
env rocks; 6s run, no crash, logs clean):
sdl-birds-11, sdl-rocks, sdl-pingus, pico-birds-11, pico-rocks.
CAVEAT: attract-screen only -- any/all behavioral audit (§3)
still needs interactive runs (e.g. rocks battle uses task pools).

Verify API matches; align drifted print strings (lua follows md).

## §2. Docs

- [ ] README.md
- [ ] guide.md
- [ ] api.md
- [ ] HISTORY.md

### 2.0 Scan recent commits for undocumented changes

- [x] Scanned 9 code commits (v0.7..v0.8). Found + fixed:
      HISTORY missing `emit(n,e)` transparent-target fix;
      api.md missing any/all non-empty/unbuffered note.
      `{tag='spawn',T,...}` already in api.md (298, 315).
      c661d73 = error-attribution polish, not HISTORY-worthy;
      e065394/e66f4d6 folded into the any/all Modifications.

### 2.1 README.md

- [x] Add `v0.8` to version list; stable link -> `v0.8`
- [x] `Install & Run`: `install atmos 0.8`
- [x] Re-check every example (verified vs tst/readme.lua in §1)
- [x] Environments section up to date (clock + 5 repos, ok)

### 2.2 HISTORY.md

- [x] `v0.8` entry complete (2.0 additions), date set `aug/26`

### 2.3 Rockspec description

- [x] `detailed` (0.7-2) == README About verbatim; no stale
      terms (`loop_on` still valid). 0.8-1 copies it unchanged.

### 2.4 guide.md

- [x] Walk every snippet against the v0.8 API (done in §1)
- [x] Terminology aligned with api.md (task/xtask ok;
      any/all pools guide-undocumented -- pre-existing, api leads)

### 2.5 api.md

- [x] `{tag='spawn',T,...}` present (298, 315)
- [x] any/all non-empty/unbuffered note added (§2.0)
- [x] Anchor check all 3 docs: fixed `#xtask-t` +
      2x `#await-pat-` in api.md; rest resolve

## §3. Migrate siblings (NO mechanical break -- audit only)

`loop_on` removal deferred to v0.9 -> no sed rewrites.
Per repo (own checkout/session):

- Audit `await(ts,'any'/'all')` sites for the new
  non-empty / unbuffered semantics (behavioral, grep won't
  catch breakage -- run the apps).
- Bump rockspec dep `atmos ~> 0.7` -> `atmos ~> 0.8`.

### Per-repo any/all sites (fill before auditing)

```
repo         any/all   notes
env-sdl      -
env-pico     -
env-socket   -
env-iup      -
sdl-birds    -
sdl-rocks    -
sdl-pingus   -
pico-birds   -
pico-rocks   -
```

## §4. Rockspec (atmos core)

- [x] Create `atmos-0.8-1.rockspec` (copy 0.7-2;
      `source.branch = v0.8`; desc unchanged; ADDED missing
      `exs.hello-rx` module -- absent since 0.7-2)
- [x] Refresh `atmos-dev-4.rockspec` (replaces dev-3, removed;
      also gains `exs.hello-rx`)
- [x] Local install (user, 2026-08-17):
      `sudo luarocks --lua-version=5.4 make atmos-0.8-1.rockspec`
      + tst all/readme/guide green vs installed rock

## §5. Release all environments and apps

Per-env release loop (8 steps; each env has its own plan):

1. [ ] Migrate to v0.8 API (§3)
2. [ ] Update README (app/atmos/env versions)
3. [ ] Phase 1 tests (local, LUA_PATH trick)
4. [ ] Create rockspec(s) (`<rev>` + `dev`)
5. [ ] Make rockspec (global install)
6. [ ] Phase 2 tests (global)
7. [ ] Commit, push `vN`; ff `main` to `vN`
8. [ ] Create/update version branch `vN`, push

New env versions -> all FIRST uploads (no skip decision:
envs pin `atmos ~> 0.8`, so every env MUST re-release).

WHY a full vN bump even with 0 code commits (sdl/socket/iup):
a dep pin is FUNCTIONAL, not metadata -- a `0.2-2` rev with
`atmos ~> 0.8` would hijack "0.2" (latest rev wins) and make
the tested 0.2+atmos-0.7 pairing unreachable. New vN preserves
the old stable pairing forever.

### Envs

- [x] env-sdl     `v0.3`  (2026-08-17; §7 upload pending)
- [ ] env-pico    `v0.4`
- [ ] env-socket  `v0.3`
- [ ] env-iup     `v0.3`
- [-] env-js      WON'T DO (user, 2026-08-15)

### Downstream apps (tracked under their env)

- [x] sdl-birds / sdl-rocks / sdl-pingus   `v0.6`
      branched, README bumped (atmos 0.8 / env-sdl 0.3 / v0.6);
      smoke-ran §1. PENDING: commit+push (user)
- [x] pico-birds / pico-rocks              `v0.7`
      branched, README bumped (atmos 0.8 / env-pico 0.4 / v0.7);
      carry UNCOMMITTED pico-sdl-0.7 API migrations
      (text.dyn/fix, layer.images table form; birds 10 files,
      rocks 2 files); smoke-ran §1. ⛔ pico-sdl 0.7 barrier.
      PENDING: commit+push (user)
- [-] iup-7guis   WON'T DO (tier C)

### clock (atmos built-in)

- [ ] `atmos/env/clock/exs/hello.lua`
- [ ] `atmos/env/clock/exs/hello-rx.lua`

## ⛔ BARRIER (if any) -- HOLD §6-§9

Named per GATES decision. Pre-barrier: §1-§5 + local verify.

BARRIER (named 2026-08-15): pico-sdl 0.7 release (user, own
repo/session) -- env-pico 0.4-1 pins `pico-sdl ~> 0.7` for the
`text.dyn` fix; do not upload it before pico-sdl 0.7 is live.
Other rocks (atmos, sdl, socket, iup) are NOT gated by it.
atmos-lang barrier still UNDECIDED (see GATES).

## §6. Commit, push main, create release branch  (⛔)

- [ ] Push main, GitHub Actions CI green
- [ ] Create branch `v0.8`, push
- [ ] Verify `main == v0.8 == origin/main`
- [ ] Verify EVERY in-scope repo HEAD == `vN`, local == remote,
      main ff'd

## §7. Publish rockspecs to LuaRocks  (⛔)

Check server first: `luarocks --lua-version=5.4 search atmos`.

```bash
luarocks --lua-version=5.4 upload atmos-0.8-1.rockspec
luarocks --lua-version=5.4 upload atmos-env-sdl-0.3-1.rockspec
luarocks --lua-version=5.4 upload atmos-env-pico-0.4-1.rockspec
luarocks --lua-version=5.4 upload atmos-env-socket-0.3-1.rockspec
luarocks --lua-version=5.4 upload atmos-env-iup-0.3-1.rockspec
```

## §8. Verify LuaRocks install + test all examples (REMOTE)

### 8.1 Clean install of published rocks  (⛔; needs §7)

```bash
sudo luarocks --lua-version=5.4 remove atmos --force
sudo luarocks --lua-version=5.4 install atmos 0.8
sudo luarocks --lua-version=5.4 install atmos-env-sdl 0.3
sudo luarocks --lua-version=5.4 install atmos-env-pico 0.4
sudo luarocks --lua-version=5.4 install atmos-env-socket 0.3
sudo luarocks --lua-version=5.4 install atmos-env-iup 0.3
```

### 8.2 Phase A -- HEADLESS

- [ ] clock hello / hello-rx
- [ ] socket hello / cli-srv

### 8.3 Phase B -- NEEDS DISPLAY

- [ ] env-sdl   hello / across / click-drag-cancel
- [ ] env-pico  hello / across / click-drag-cancel
- [ ] env-iup   hello / button-counter / iup-net
- [ ] sdl-birds / sdl-rocks / sdl-pingus  (v0.6)
- [ ] pico-birds / pico-rocks             (v0.7)

### 8.4 Gotchas

- env-sdl needs `DejaVuSans.ttf` in cwd.
- pico uses the `pico-lua` binary.
- `iup-net` needs atmos-env-socket.
- `--force` remove wipes local dev `make`; restore per repo.
- after app runs, `git checkout main`/`master`.

## §9. Announce (manual)  (⛔)

- [ ] Twitter / BlueSky
- [ ] Mailing list
- [ ] Students
