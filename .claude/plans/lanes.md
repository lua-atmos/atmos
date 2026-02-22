# thread (LuaLanes)

Run a plain Lua function in an OS thread via LuaLanes, then poll for its result
inside the atmos scheduler.

## Status: done

## Design

`thread(arg1, arg2, ..., f)` — last argument is the body function.

### Constraints

- The body function **must not** capture upvalues (beyond `_ENV`).
  Lanes serializes bytecode, so upvalues are silently lost.
  `debug.getupvalue` is checked at call time; violation is an `assertn` error.
- Arguments are **copied** by value (tables are deep-copied by Lanes).
  Mutations inside the lane do not affect the parent.

### Implementation (`atmos/run.lua`)

```
lazy-require lanes (module-level local, initialized on first call)
    local lanes
    ...
M.thread(...)
    lanes = lanes or require("lanes").configure()
    -- validation: body is a function, caller is inside a task, no upvalues

    local linda    = lanes.linda()
    local bytecode = string.dump(f)

    -- gen: create a lane prototype that imports all libs
    local proto = assert(lanes.gen("*", function (linda, f_bytecode, ...)
        local f = load(f_bytecode)
        (function (ok, ...)                        -- capture pcall returns
            if ok then
                linda:send("ok", true, ...)        -- forward all returns
            else
                linda:send("ok", false, tostring((...)))
            end
        end)(pcall(f, ...))
    end))

    -- call: launch the lane, then register cancel-on-close
    local lane = assert(proto(linda, bytecode, table.unpack(args)))
    local _ <close> = M.defer(function ()
        pcall(function () lane:cancel(0, true) end)
    end)

    -- poll: wake on any event, check if lane posted a result
    while true do
        local r = table.pack((function (key, ...)
            if key then return ... end
        end)(linda:receive(0, "ok")))
        if r.n > 0 then
            if r[1] then
                return table.unpack(r, 2, r.n)    -- multiple returns
            else
                error(r[2], 0)                     -- propagate lane error
            end
        end
        M.await(true)
    end
```

### Key decisions

| decision | choice | why |
|---|---|---|
| linda key name | `"ok"` | matches the boolean it carries |
| library imports | `"*"` (all) | avoids surprises when lane code uses any stdlib |
| multiple returns | `linda:send("ok", true, ...)` | no table wrapper; use `(function(key,...) ... end)(linda:receive(...))` trick to unpack |
| error serialization | `tostring(err)` on send side | error objects can't cross lane boundaries |
| defer placement | after `proto(...)` call | `lane` is always set, no nil guard needed |
| cancel strategy | `lane:cancel(0, true)` inside `pcall` | immediate soft-cancel; pcall absorbs errors if lane already finished |

### Section placement

`M.thread` sits in its own `----` section **after toggle, before every/par**.

### Global (`atmos/init.lua`)

```lua
thread = run.thread
```

### CI/CD (`.github/workflows/test.yml`)

```yaml
- name: Install Lua
  run: |
    sudo apt-get update
    sudo apt-get install -y lua5.4 luarocks
- name: Install LuaLanes
  run: sudo luarocks install lanes
```

### Tests (`tst/thread.lua`)

- error: no enclosing task
- error: no body function
- error: captures external variable
- basic: no return
- basic: return value
- parameters: copied values
- parameters: table copy
- string operations (string lib)
- math operations (math lib)
- error propagation from lane
- parent suspends during thread
- sequential threads
- thread inside par_or
- table isolation (mutation doesn't cross)
