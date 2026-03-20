# Extract Envs from Atmos

## Context

The atmos repo currently bundles 5 environments (clock, sdl, pico,
socket, iup) under `atmos/env/`.
Goal: keep only `clock` in this repo and extract the rest into
separate repos, starting with SDL → `env-sdl`.

## Step 1 — Create `env-sdl` repo (flat layout)

New repo at `/x/lua-atmos/env-sdl`

```
env-sdl/
├── init.lua                  ← from atmos/env/sdl/init.lua
├── README.md                 ← updated links
├── exs/
│   ├── hello.lua
│   ├── click-drag-cancel.lua
│   ├── across.lua
│   └── DejaVuSans.ttf
└── env-sdl-0.1-1.rockspec   ← new (deps: atmos, lua-sdl2)
```

### Changes to init.lua

- `require "atmos.util"` stays (dependency on atmos)
- Module registers via `atmos.env(M)` — stays
- No path changes needed for the Lua code itself

### Rockspec (`env-sdl-0.1-1.rockspec`)

- package: `env-sdl`
- dependencies: `lua >= 5.4`, `atmos >= 0.5`, `lua-sdl2`
- modules:
    - `atmos.env.sdl.init` = `init.lua`
    - example files in exs/

### README.md

- Update relative links (no longer inside atmos tree)
- Point to atmos as a dependency

## Step 2 — Remove non-clock envs from atmos

| Target                   | Action                             |
| ------------------------ | ---------------------------------- |
| `atmos/env/sdl/`         | delete                             |
| `atmos/env/pico/`        | delete                             |
| `atmos/env/socket/`      | delete                             |
| `atmos/env/iup/`         | delete                             |
| `atmos-0.5-1.rockspec`   | remove non-clock env module entries |

### Files to keep

- `atmos/env/clock/` (init.lua, exs/, README.md)

## Step 3 — Verify

- `atmos/env/` contains only `clock/`
- rockspec lists only clock modules
- tests still pass: `cd tst && lua5.4 all.lua`

## Progress

- [ ] Step 1 — Create env-sdl repo
- [ ] Step 2 — Remove non-clock envs from atmos
- [ ] Step 3 — Verify
