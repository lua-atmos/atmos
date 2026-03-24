# Atmos

[![Tests][badge]][test]

[badge]: https://github.com/lua-atmos/atmos/actions/workflows/test.yml/badge.svg
[test]:  https://github.com/lua-atmos/atmos/actions/workflows/test.yml

***Structured Event-Driven Concurrency for Lua***

[
    [`v0.6`](https://github.com/lua-atmos/atmos/tree/v0.6)      |
    [`v0.5`](https://github.com/lua-atmos/atmos/tree/v0.5)      |
    [`v0.4`](https://github.com/lua-atmos/atmos/tree/v0.4)      |
    [`v0.3`](https://github.com/lua-atmos/atmos/tree/v0.3)      |
    [`v0.2.1`](https://github.com/lua-atmos/atmos/tree/v0.2.1)  |
    [`v0.1`](https://github.com/lua-atmos/atmos/tree/v0.1)
]

Stable branch is [`v0.6`](https://github.com/lua-atmos/atmos/tree/v0.6).

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
Concurrency][sc]* and *[Event-Driven Programming][events]*, extending classical
structured programming with two main functionalities:

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

Atmos also complements its core synchronous concurrency model with
    *[Functional Streams][streams]* (à la [ReactiveX][rx]) and
    [Multithreading Parallelism][threads] (via [LuaLanes][lanes]):

- Functional Streams:
    - Interoperability with tasks & events.
    - Safe finalization of stateful streams.
- Asynchronous Parallelism:
    - A `thread` primitive offloads computations to isolated OS threads.
    - Safe abortion and finalization for threads.

Atmos is inspired by [synchronous programming languages][sync] like [Céu][ceu]
and [Esterel][esterel].

[lua]:          https://www.lua.org/
[sc]:           https://en.wikipedia.org/wiki/Structured_concurrency
[events]:       https://en.wikipedia.org/wiki/Event-driven_programming

[streams]:      https://en.wikipedia.org/wiki/Stream_(abstract_data_type)
[rx]:           https://en.wikipedia.org/wiki/ReactiveX
[threads]:      https://en.wikipedia.org/wiki/Thread_(computing)
[lanes]:        https://lualanes.github.io/lanes/

[sync]:         https://fsantanna.github.io/sc.html
[ceu]:          http://www.ceu-lang.org/
[esterel]:      https://en.wikipedia.org/wiki/Esterel

# Hello World!

During 5 seconds, displays `Hello World!` every second:

```
require "atmos.env.clock"

loop(function ()
    watching(clock{s=5}, function ()
        every(clock{s=1}, function ()
            print("Hello World!")
        end)
    end)
end)
```

We first import the builtin `clock` environment, which provides timers to
applications.
The `loop` primitive receives a function with the application logic in Atmos,
as follows:

- The `watching` command will execute its inner function during 5 seconds.
- The `every` loop will execute its inner function every second.
- Once the `watching` terminates, the `loop` returns back to Lua.

In Atmos, the lifetimes and schedules of tasks are determined by lexical
structure.
Tasks that would awake "simultaneously" instead do so in order of appearance in
the source code.
This enables reasoning about programs more statically based on the structure of
the source code.
Tasks that abort also abort their inner tasks, which have a "last chance" to
execute if applicable.
Applying this to the above example:

- On the first, second, third, and fourth second, `every` awakes and prints
  `"Hello World!"`
- On the fifth second, `watching` and `every` are both scheduled to awake.
- The `every` awakes before the enclosing `watching`, printing `"Hello World!"`
  for the fifth (and last) time.
- Therefore, `loop` returns after five seconds having printed `"Hello World!"`
  five times.

See [the relevant section in the guide](guide.md#31-lexical-scheduling) for
other, more complex examples.

# Install & Run

```
sudo luarocks --lua-version=5.4 install atmos 0.6
lua5.4 <lua-path>/atmos/env/clock/exs/hello.lua
```

You may also clone the repository and copy part of the source tree, as follows,
into your Lua path (e.g., `/usr/local/share/lua/5.4`):

```
atmos/
├── env/
│   └── clock/
│       ├── exs/
│       │   ├── hello.lua
│       │   └── hello-rx.lua
│       └── init.lua
├── init.lua
├── run.lua
├── streams.lua
├── util.lua
└── x.lua
```

Atmos depends on [f-streams][f-streams].

[f-streams]: https://github.com/lua-atmos/f-streams/

# Environments

An environment is an external component that bridges input events from the real
world into an Atmos application.

The standard distribution of Atmos provides a simple `clock` environment to
experiment with time.

All other environments are available as separate packages:

- [`atmos.env.clock`](atmos/env/clock/):
    A simple pure-Lua environment that uses `os.clock` to issue timer events.
- [`atmos.env.socket`](https://github.com/lua-atmos/env-socket):
    An environment that relies on [luasocket][luasocket] to provide network
    communication.
- [`atmos.env.sdl`](https://github.com/lua-atmos/env-sdl):
    An environment that relies on [lua-sdl2][luasdl] to provide window, mouse,
    key, and timer events.
- [`atmos.env.pico`](https://github.com/lua-atmos/env-pico):
    An environment that relies on [pico-lua][pico-lua] as a simpler
    alternative to SDL.
- [`atmos.env.iup`](https://github.com/lua-atmos/env-iup):
    An environment that relies on [IUP][iup] ([iup-lua][iup-lua]) to provide
    graphical user interfaces (GUIs).
- [`atmos.env.js`](https://github.com/lua-atmos/env-js/):
    An environment for running Atmos in the browser via
    [wasmoon][wasmoon] (Lua 5.4 compiled to WebAssembly).

[luasocket]:    https://lunarmodules.github.io/luasocket/
[luasdl]:       https://github.com/Tangent128/luasdl2/
[pico-lua]:     https://github.com/fsantanna/pico-sdl/tree/main/lua
[iup]:          https://www.tecgraf.puc-rio.br/iup/
[iup-lua]:      https://www.tecgraf.puc-rio.br/iup/en/basic/index.html
[wasmoon]:      https://github.com/ceifa/wasmoon

# Documentation

- [Guide](guide.md)
- [API](api.md)

# Resources

- [A toy problem][toy]: Drag, Click, or Cancel
    - [click-drag-cancel.lua](https://github.com/lua-atmos/env-pico/blob/main/exs/click-drag-cancel.lua)
- A simple but complete 2D game in Atmos:
    - https://github.com/lua-atmos/pico-rocks/
- Academic publications (Céu):
    - http://ceu-lang.org/chico/#ceu
- Mailing list (Céu & Atmos):
    - https://groups.google.com/g/ceu-lang

[toy]:  https://fsantanna.github.io/toy.html
