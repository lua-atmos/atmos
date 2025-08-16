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
git branch v-NEW
git checkout v-NEW
git push --set-upstream origin v-NEW
```

- Docs

```
git difftool v-OLD       # examine all diffs
```

- Branch

```
git branch v-NEW
git checkout v-NEW
git push --set-upstream origin v-NEW
```

- LuaRocks

```
cp atmos-OLD.rockspec atmos-NEW.rockspec
vi atmos-NEW.rockspec
    # set version, source.branch
luarocks upload atmos-NEW.rockspec --api-key=...
```

- Install

```
lua5.4 /x/lua-atmos/atmos/atmos/env/clock/exs/hello.lua
    # works

cd /usr/local/share/lua/5.4/
ls -l atmos         # check if link to dev
sudo rm atmos

lua5.4 /x/lua-atmos/atmos/atmos/env/clock/exs/hello.lua
    # fails

sudo luarocks install atmos --lua-version=5.4  # check if atmos-NEW

lua5.4 /x/lua-atmos/atmos/atmos/env/clock/exs/hello.lua
    # works
```

- Develop

```
cd /usr/local/share/lua/5.4/
sudo rm -Rf atmos/
sudo ln -s /x/lua-atmos/atmos/atmos
```
