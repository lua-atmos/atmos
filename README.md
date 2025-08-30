# Atmos

This is the unstable (probably broken) `main` branch towards `v0.3`.

For a stable release, please switch to [`v0.2.1`][v0.2.1].

[
    [`v0.3`](https://github.com/lua-atmos/atmos/tree/v0.3) |
    [`v0.2.1`][v0.2.1] |
    [`v0.1`](https://github.com/lua-atmos/atmos/tree/v0.1)
]

[v0.2.1]: https://github.com/lua-atmos/atmos/tree/v0.2.1

<img src="atmos-logo.png" width="250" align="right">

***Structured Event-Driven Concurrency for Lua***

[
    [About](#about)                 |
    [Install](#install)             |
    [Hello World!](#hello-world)    |
    [Documentation](#documentation) |
    [Resources](#resources)
]

# About

Atmos is a programming library for [Lua][lua] that reconciles *[Structured
Concurrency][sc]*, *[Event-Driven Programming][events]*, and
*[Functional Streams][rx]*, extending classical structured programming with
three main functionalities:

- Structured Deterministic Concurrency:
    - A `task` primitive with deterministic scheduling provides predictable
      behavior and safe abortion.
    - Structured primitives compose concurrent tasks with lexical scope (e.g.,
      `watching`, `every`, `par_or`).
    - A `tasks` container primitive holds attached tasks and control their
      lifecycle.
- Event Signaling Mechanisms:
    - An `await` primitive suspends a task and wait for events.
    - An `emit` primitive signal events and awake awaiting tasks.
- Pull-Based Streams (à la [JavaStreams][java-streams]):
    - Functional combinators for lazy (infinite) lists.
    - Interoperability with tasks & events:
        streams can have tasks and awaits as sources,
        streams can signal events (TODO), and
        tasks can await streams (TODO).
    - Proper finalization of stateful (task-based) streams.

Atmos is inspired by [synchronous programming languages][sync] like [Ceu][ceu]
and [Esterel][esterel].

[lua]:          https://www.lua.org/
[sc]:           https://en.wikipedia.org/wiki/Structured_concurrency
[rx]:           https://docs.oracle.com/javase/8/docs/api/java/util/stream/Stream.html
[java-streams]: https://en.wikipedia.org/wiki/Event-driven_programming
[sync]:         https://fsantanna.github.io/sc.html
[ceu]:          http://www.ceu-lang.org/
[esterel]:      https://en.wikipedia.org/wiki/Esterel

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

We first the builtin `clock` environment, which provides timers to
applications.
The `call` primitive receives a function with the application logic in Atmos,
as follows:

- The `watching` command will execute its inner function during 5 seconds.
- The `every` loop will execute its inner function every second.
- Once the `watching` terminates, the `call` returns back to Lua.

Now, the same specification, but using streams:

```
require "atmos.env.clock"
local S = require "atmos.streams"

call(function ()
    local s1 = S.from(clock{s=5}):take(1)
    local s2 = S.from(clock{s=1})
    s1:paror(s2)
        :to_each(function()
            print("Hello World!")
        end)
end)
```

# Install & Run

```
sudo luarocks install atmos --lua-version=5.4
lua5.4 <lua-path>/atmos/env/clock/exs/hello.lua
```

You may also clone the repository and copy part of the source tree, as follows,
into your Lua path (e.g., `/usr/local/share/lua/5.4`):

```
atmos
├── env/
│   ├── clock/
│   │   ├── exs/
│   │   │   ├── hello.lua
│   │   │   └── hello-rx.lua
│   │   └── init.lua
│   ├── iup/
│   │   ├── exs/
│   │   │   ├── button-counter.lua
│   │   └── init.lua
│   ├── sdl/
│   │   ├── exs/
│   │   │   ├── click-drag-cancel.lua
│   │   │   └── DejaVuSans.ttf
│   │   └── init.lua
│   └── socket/
│       ├── exs/
│       │   └── cli-srv.lua
│       └── init.lua
├── init.lua
├── run.lua
├── streams.lua
└── util.lua
```

Atmos depends on [f-streams][f-streams].

[f-streams]: https://github.com/lua-atmos/f-streams/

# Documentation

- [Guide](guide.md)
- [API](api.md)

# Environments

An environment is an external component that bridges input events from the real
world into an Atmos application.

The standard distribution of Atmos provides the following environments:

- [`atmos.env.clock`](atmos/env/clock/):
    A simple pure-Lua environment that uses `os.clock` to issue timer events.
- [`atmos.env.socket`](atmos/env/socket/):
    An environment that relies on [luasocket][luasocket] to provide network
    communication.
- [`atmos.env.sdl`](atmos/env/sdl/):
    An environment that relies on [lua-sdl2][luasdl] to provide window, mouse,
    key, and timer events.
- [`atmos.env.iup`](atmos/env/iup/):
    An environment that relies on [IUP][iup] ([iup-lua][iup-lua]) to provide
    graphical user interfaces (GUIs).

[luasocket]:    https://lunarmodules.github.io/luasocket/
[luasdl]:       https://github.com/Tangent128/luasdl2/
[iup]:          https://www.tecgraf.puc-rio.br/iup/
[iup-lua]:      https://www.tecgraf.puc-rio.br/iup/en/basic/index.html

# Resources

- [A toy problem][toy]: Drag, Click, or Cancel
    - [click-drag-cancel.lua](atmos/env/sdl/exs/click-drag-cancel.lua)
- A simple but complete 2D game in Atmos:
    - https://github.com/lua-atmos/sdl-rocks/
- Academic publications (Ceu):
    - http://ceu-lang.org/chico/#ceu
- Mailing list (Ceu):
    - https://groups.google.com/g/ceu-lang

[toy]:  https://fsantanna.github.io/toy.html
