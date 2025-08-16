# Tests

- Self tests:

```
cd tst/
lua5.4 all.lua
```

- Environments

```
cd atmos/env/
find . -path "*/exs/*" -type f -name "*.lua"
lua5.4 * # test each example
```

- Projects
    - `sdl-birds/`
        - `lua5.4 birds-11.lua`
    - `sdl-pingus/`
        - `lua5.4 main.lua`
    - `sdl-rocks/`
        - `lua5.4 main.lua`
    - `iup-7guis/`
        - `lua5.4 03-flight.lua`
        - `lua5.4 server.lua` + `lua5.4 01-counter-net.lua`

```
git branch              # should be in `main`
git checkout main
git pull                # ensure newest `main`
git branch v-new
git checkout v-new
git push --set-upstream origin v-new
```

- Docs

```
git difftool vOLD       # examine all diffs
```

- Branch

```
git branch vA.B.c
git push --origin
```

- LuaRocks

```
cp atmos-OLD.rockspec atmos-NEW.rockspec
vi atmos-NEW.rockspec
    # version, source.branch
```
