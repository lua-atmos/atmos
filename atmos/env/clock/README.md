# atmos.env.clock

A simple `clock` environment for [lua-atmos](../../../).

# Run

```
lua5.4 <lua-path>/atmos/env/clock/exs/hello.lua
```

# Hello World!

During 5 seconds, displays `Hello World!` every second:

```
require "atmos.env.clock"

call(function ()
    watching(clock{s=5}, function ()
        every(clock{s=1}, function ()
            print("Hello World!")
        end)
    end)
end)
```

# Events

- `clock`

# Source

Assumes this directory structure:

```
.
├── atmos/
│   └── atmos
│       └── env
│           └── clock   <-- we are here
└── f-streams/
```

```bash
LUA_PATH="../../../../f-streams/?/init.lua;../../../?.lua;../../../?/init.lua;;" lua5.4 exs/hello.lua
```
