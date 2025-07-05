# `lua-atmos` (`v0.1`)

<img src="atmos-logo.png" align="right">

<b>Structured Event-Driven Concurrency for Lua</b>

[
    [About](#about)                 |
    [Install](#install)             |
    [Hello World!](#hello-world)    |
    [Documentation](#documentation) |
    [Resources](#resources)
]

# About

Atmos is a programming library for [Lua][1] that reconciles *[Structured
Concurrency][2]* with *[Event-Driven Programming][3]*, extending classical
structured programming with two main functionalities:

- Structured Deterministic Concurrency:
    - The `task` primitive with deterministic scheduling provides predictable
      behavior and safe abortion.
    - Structured primitives compose concurrent tasks with lexical scope (e.g.,
      `watching`, `every`, `par_or`).
    - The `tasks` container primitive holds attached tasks and control their
      lifecycle.
- Event Signaling Mechanisms:
    - The `await` primitive suspends a task and wait for events.
    - The `emit` primitive signal events and awake awaiting tasks.

Atmos is inspired by [synchronous programming languages][4] like [Ceu][5] and
[Esterel][6].

# Install & Run

```
sudo luarocks install atmos --lua-version=5.4
lua5.4 <lua-path>/atmos/env/clock/exs/hello.lua
```

You may also copy the source tree to your Lua path (e.g.,
`/usr/local/share/lua/5.4`):

```
atmos/
  |-- run.lua
  |-- init.lua
  |-- util.lua
  +-- env/
    +-- sdl/
      +-- exs/
        |-- click-drag-cancel.lua
      |-- init.lua
    +-- clock/
      +-- exs/
        |-- hello.lua
      |-- init.lua
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

We first import the library with the builtin `clock` environment, which
provides timers to applications.
The `call` primitive receives a function with the application logic in Atmos,
as follows:

- The `watching` command will execute its inner function during 5 seconds.
- The `every` loop will execute its inner function every second.
- After the `watching` terminates, the `call` returns back to Lua.

# Documentation

- [Guide](guide.md)
- [API](api.md)

# Environments

An environment is an external component that bridges input events from the real
world into an Atmos application.

The standard distribution of Atmos provides the following environments:

- `atmos.env.clock`:
    A simple pure-Lua environment that uses `os.clock` to issue timer events.
- `atmos.env.sdl`:
    An environment that relies on [lua-sdl2][7] to provide window, mouse, key,
    and timer events.

# Resources

- [A toy problem][8]: Drag, Click, or Cancel
    - https://github.com/lua-atmos/atmos/blob/v0.1/atmos/env/sdl/exs/click-drag-cancel.lua
- A simple but complete 2D game in Atmos:
    - https://github.com/lua-atmos/sdl-rocks/tree/v0.1
- Academic publications (Ceu):
    - http://ceu-lang.org/chico/#ceu
- Mailing list (Ceu):
    - https://groups.google.com/g/ceu-lang

[1]: https://www.lua.org/
[2]: https://en.wikipedia.org/wiki/Structured_concurrency
[3]: https://en.wikipedia.org/wiki/Event-driven_programming
[4]: https://fsantanna.github.io/sc.html
[5]: http://www.ceu-lang.org/
[6]: https://en.wikipedia.org/wiki/Esterel
[7]: https://github.com/Tangent128/luasdl2/
[8]: https://fsantanna.github.io/toy.html
