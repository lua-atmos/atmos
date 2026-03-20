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

```bash
LUA_PATH="../../f-streams/?/init.lua;../?.lua;../?/init.lua;;" lua5.4 all.lua
```
