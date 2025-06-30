# lua-atmos (v0.1)

[
    [About](#about)                 |
    [Hello World!](#hello-world)    |
    [Install](#install)             |
    [Documentation](#documentation) |
    [Resource](#resources)
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

Atmos is inspired by [synchronous programming languages][4] like as [Ceu][5]
and [Esterel][6].

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

# Install

`TODO`

# Documentation

- [Guide](guide.md)
- [API](api.md)

# Resources

- A toy Problem: Drag, Click, or Cancel
    - https://fsantanna.github.io/toy.html
    - Implementation in Atmos and SDL:
        - https://github.com/lua-atmos/atmos/blob/main/atmos/env/sdl/exs/click-drag-cancel.lua
- A simple but complete 2D game in Atmos:
    - https://github.com/lua-atmos/sdl-rocks
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
[7]: https://github.com/Tangent128/luasdl2
