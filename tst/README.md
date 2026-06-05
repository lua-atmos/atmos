Install `lanes`:

```
sudo luarocks --lua-version=5.4 install lanes
```

Assumes this directory structure:

```
.
├── atmos
│   ├── atmos
│   └── tst     <-- we are here
└── f-streams
```

Default:

```bash
LUA_PATH="../../f-streams/?/init.lua;../?.lua;../?/init.lua;;" lua5.4 all.lua
```

Worktree:

```bash
LUA_PATH="../../../../f-streams/?/init.lua;../?.lua;../?/init.lua;;" lua5.4 all.lua
```

Absolute:

```bash
LUA_PATH="/XXX/f-streams/?/init.lua;/XXX/atmos/XXX/?.lua;/XXX/atmos/XXX/?/init.lua;;" lua5.4 all.lua
```
