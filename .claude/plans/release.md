# Plan: Release v0.6

## Context

Atmos v0.5 bundled 5 environments. For v0.6, envs (except clock)
are extracted to separate repos. New features since v0.5 include
thread cancel, thread no-args, and the env extraction itself.
This plan uses release branches (not tags) for versioning.

## Pending from extract-envs

- [ ] Update rockspec: remove non-clock env module entries
- [ ] Update README.md: remove bundled env tree, update env
      links to point to separate repos
- [ ] Rockspecs for extracted envs must install into `atmos/env/*`
    - env-sdl
    - env-socket
    - env-iup
    - env-pico

## Steps

### 1. Run tests

```bash
cd tst && lua5.4 all.lua
```

### 1b. Test all env examples (manual)

**clock** (atmos built-in):
- [ ] `atmos/env/clock/exs/hello.lua`
- [ ] `atmos/env/clock/exs/hello-rx.lua`

**env-sdl** (`/x/lua-atmos/env-sdl`):
- [ ] `exs/hello.lua`
- [ ] `exs/across.lua`
- [ ] `exs/click-drag-cancel.lua`

**env-pico** (`/x/lua-atmos/env-pico`):
Note: requires pico-sdl v0.3 (`sudo luarocks --lua-version=5.4 install pico-sdl 0.3`)
- [ ] `exs/hello.lua`
- [ ] `exs/across.lua`
- [ ] `exs/click-drag-cancel.lua`

**env-socket** (`/x/lua-atmos/env-socket`):
- [ ] `exs/hello.lua`
- [ ] `exs/cli-srv.lua`

**env-iup** (not yet extracted):
- [ ] `atmos/env/iup/exs/hello.lua`
- [ ] `atmos/env/iup/exs/button-counter.lua`
- [ ] `atmos/env/iup/exs/iup-net.lua`

**pico-rocks** (`/x/lua-atmos/pico-rocks`):
- [ ] `main.lua`

**sdl-rocks** (`/x/lua-atmos/sdl-rocks`):
- [ ] `main.lua`

**iup-7guis** (`/x/lua-atmos/iup-7guis`):
- [ ] `01-counter.lua`
- [ ] `02-temperature.lua`
- [ ] `03-flight.lua`
- [ ] `01-counter-net.lua`

**env-js**:
- [ ] generate pages

### 2. Create rockspec `atmos-0.6-1.rockspec`

- Copy from `atmos-0.5-1.rockspec`
- Change `version` to `"0.6-1"`
- Change `branch` to `"v0.6"`
- Remove all non-clock env modules (sdl, pico, socket, iup)
- Move old rockspec to `old/`

### 3. Update `README.md`

- Add `v0.6` to version list
- Update stable link from `v0.5` to `v0.6`
- Update `Install & Run` section: `install atmos 0.6`
- Remove bundled env directory tree (only clock remains)
- Update Environments section:
    - clock stays as bundled
    - sdl, pico, socket, iup → link to separate repos
      (lua-atmos/env-sdl, env-pico, env-socket, env-iup)

### 4. Update `HISTORY.md`

```
v0.6 (mar/26)
-------------

- Extracted environments to separate repos:
    - env-sdl, env-pico, env-socket, env-iup
- Thread cancel
- Thread no-args
```

### 5. Commit all changes

Single commit: `release: v0.6`

### 6. Push main

```bash
git push origin main
```

Check GitHub Actions for green CI.

### 7. Create release branch and push

```bash
git checkout -b v0.6
```

- Update README links: `main` → `v0.6`
- Commit and push

```bash
git push origin v0.6
git checkout main
```

### 8. Publish to LuaRocks

```bash
luarocks upload atmos-0.6-1.rockspec
```

### 9. Verify LuaRocks install

```bash
sudo luarocks --lua-version=5.4 remove atmos
sudo luarocks --lua-version=5.4 install atmos 0.6
lua5.4 <lua-path>/atmos/env/clock/exs/hello.lua
```

### 10. Release all environments and apps

- [ ] env-sdl
- [ ] env-pico
- [ ] env-socket
- [ ] env-iup
- [ ] env-js
- [ ] pico-rocks
- [ ] sdl-rocks
- [ ] iup-7guis

### 11. Announce (manual)

- Mailing list
- Students

## Files to modify

| File                      | Change                                  |
| ------------------------- | --------------------------------------- |
| `atmos-0.6-1.rockspec`   | new (from 0.5, updated)                 |
| `old/`                    | move old rockspec here                  |
| `README.md`               | version list, stable link, env links    |
| `HISTORY.md`              | v0.6 entry                              |

## Progress

- [ ] Pending: rockspec cleanup (from extract-envs)
- [ ] Pending: README env links (from extract-envs)
- [ ] Pending: extracted env rockspecs install into atmos/env/*
- [ ] Step 1 — Run tests
- [ ] Step 2 — Create rockspec
- [ ] Step 3 — Update README
- [ ] Step 4 — Update HISTORY
- [ ] Step 5 — Commit
- [ ] Step 6 — Push main
- [ ] Step 7 — Create release branch
- [ ] Step 8 — Publish to LuaRocks
- [ ] Step 9 — Verify install
- [ ] Step 10 — Announce
