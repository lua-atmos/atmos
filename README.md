# lua-atmos (v0.1)

`lua-atmos` is a [synchronous programming][1] library for [Lua][2] that
reconciles *[Structured Concurrency][3]* with *[Event-Driven Programming][4]*
in order to extend classical structured programming with two main
functionalities:

- Structured Deterministic Concurrency:
    - A set of structured primitives to lexically compose concurrent tasks
      (e.g., `spawn`, `par_or`, `every`).
    - A synchronous and deterministic scheduling policy, which provides
      predictable behavior and safe abortion of tasks.
    - A container primitive to hold dynamic tasks, which automatically releases
      them as they terminate.
- Event Signaling Mechanisms:
    - An `await` primitive to suspend a task and wait for events.
    - An `emit` primitive to signal events and awake awaiting tasks.

`lua-atmos` is inspired by [Ceu][5], which is inpired by [Esterel][6].

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
The `call` primitive receives a function with the application logic:
- The `watching` command will execute its inner function during 5 seconds.
- The `every` loop will execute its inner function every second.
- The `call` returns after the `watching` terminates.

The library expects a call to `loop`, which passes the control to the
environment

 primitive expects a function 

# Install

# Documentation

## Guide

## Manual

[1]: https://www.lua.org/
[2]: https://fsantanna.github.io/sc.html
[3]: https://en.wikipedia.org/wiki/Structured_concurrency
[4]: https://en.wikipedia.org/wiki/Event-driven_programming
[5]: https://www.ceu-lang.org/
[6]: https://en.wikipedia.org/wiki/Esterel
