# Atmos

***Structured Event-Driven Concurrency for Lua***

[
    [`v0.4`](https://github.com/lua-atmos/atmos/tree/v0.4)      |
    [`v0.3`](https://github.com/lua-atmos/atmos/tree/v0.3)      |
    [`v0.2.1`](https://github.com/lua-atmos/atmos/tree/v0.2.1)  |
    [`v0.1`](https://github.com/lua-atmos/atmos/tree/v0.1)
]

This is the unstable `main` branch.
Please, switch to stable [`v0.4`](https://github.com/lua-atmos/atmos/tree/v0.4).
<!--
-->

[
    [About](#about)                 |
    [Hello World!](#hello-world)    |
    [Install & Run](#install--run)  |
    [Environments](#environments)   |
    [Documentation](#documentation) |
    [Resources](#resources)
]

<img src="atmos-logo.png" width="250" align="right">

# About

Atmos is a programming library for [Lua][lua] that reconciles *[Structured
Concurrency][sc]*, *[Event-Driven Programming][events]*, and
*[Functional Streams][streams]*, extending classical structured programming
with three main functionalities:

- Structured Deterministic Concurrency:
    - A `task` primitive with deterministic scheduling provides predictable
      behavior and safe abortion.
    - Structured primitives compose concurrent tasks with lexical scope (e.g.,
      `watching`, `every`, `par_or`).
    - A `tasks` container primitive holds attached tasks and control their
      lifecycle.
- Event Signaling Mechanisms:
    - An `await` primitive suspends a task and wait for events.
    - An `emit` primitive signals events and awake awaiting tasks.
- Functional Streams (à la [ReactiveX][rx]):
    - Functional combinators for lazy (infinite) lists.
    - Interoperability with tasks & events:
        tasks and events as streams, and
        streams as events.
    - Safe finalization of stateful (task-based) streams.

Atmos is inspired by [synchronous programming languages][sync] like [Céu][ceu]
and [Esterel][esterel].

[lua]:          https://www.lua.org/
[sc]:           https://en.wikipedia.org/wiki/Structured_concurrency
[streams]:      https://en.wikipedia.org/wiki/Stream_(abstract_data_type)
[events]:       https://en.wikipedia.org/wiki/Event-driven_programming
[rx]:           https://en.wikipedia.org/wiki/ReactiveX
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

We first import the builtin `clock` environment, which provides timers to
applications.
The `call` primitive receives a function with the application logic in Atmos,
as follows:

- The `watching` command will execute its inner function during 5 seconds.
- The `every` loop will execute its inner function every second.
- Once the `watching` terminates, the `call` returns back to Lua.

In Atmos, the lifetimes and schedules of tasks are determined by lexical 
structure.
Tasks that would awake "simultaneously" instead do so in order of appearance in
the source code.
This enables reasoning about programs more statically based on the structure of
the source code.
Tasks that abort also abort their inner taks, which have a "last chance" to
execute if applicable.
Applying this to the above example:

- On the first, second, third, and fourth second, `every` awakes and prints
  `"Hello World!"`
- On the fifth second, `watching` and `every` are both scheduled to awake.
- The `every` awakes before the enclosing `watching`, printing `"Hello World!"`
  for the fifth (and last) time.
- Therefore, `call` returns after five seconds having printed `"Hello World!"`
  five times.

See [the relevant section in the guide](guide.md#31-lexical-scheduling) for 
other, more complex examples.

Now, the same specification, but using streams:

```
require "atmos.env.clock"
local S = require "atmos.streams"

call(function ()
    local s1 = S.from(clock{s=1})
        :tap(function()
            print("Hello World!")
        end)
    local s2 = S.from(clock{s=5}):take(1)
    S.paror(s1,s2):to() -- note that s1 comes before s2!
end)
```

- `s1` is a periodic 1-second stream that prints the message on every
  occurrence, through the `tap` combinator.
- `s2` is a periodic 5-seconds stream that terminates after its first
  occurrence, because of `take(1)`.
- `S.paror` merges the streams, terminating when either of them terminate.
- `to` is a sink that starts and exausts the full stream pipeline.

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
│   │   │   └── button-counter.lua
│   │   └── init.lua
│   ├── pico/
│   │   ├── exs/
│   │   │   └── click-drag-cancel.lua
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
- [`atmos.env.pico`](atmos/env/pico/):
    An environment that relies on [pico-sdl-lua][pico-sdl-lua] as a simpler
    alternative do SDL.
- [`atmos.env.iup`](atmos/env/iup/):
    An environment that relies on [IUP][iup] ([iup-lua][iup-lua]) to provide
    graphical user interfaces (GUIs).

[luasocket]:    https://lunarmodules.github.io/luasocket/
[luasdl]:       https://github.com/Tangent128/luasdl2/
[pico-sdl-lua]: https://github.com/fsantanna/pico-sdl/tree/main/lua
[iup]:          https://www.tecgraf.puc-rio.br/iup/
[iup-lua]:      https://www.tecgraf.puc-rio.br/iup/en/basic/index.html

# Documentation

- [Guide](guide.md)
- [API](api.md)

# Resources

- [A toy problem][toy]: Drag, Click, or Cancel
    - [click-drag-cancel.lua](atmos/env/pico/exs/click-drag-cancel.lua)
- A simple but complete 2D game in Atmos:
    - https://github.com/lua-atmos/pico-rocks/
- Academic publications (Céu):
    - http://ceu-lang.org/chico/#ceu
- Mailing list (Céu & Atmos):
    - https://groups.google.com/g/ceu-lang

[toy]:  https://fsantanna.github.io/toy.html
