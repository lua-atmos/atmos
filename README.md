# lua-atmos (v0.1)

`lua-atmos` is a [synchronous programming][1] library for [Lua][2] that
reconciles *[Structured Concurrency][3]* with *[Event-Driven Programming][4]*
in order to extend classical structured programming with two main
functionalities:

- Structured Deterministic Concurrency:
    - A task primitive with synchronous and deterministic scheduling, which
      provides predictable behavior and safe abortion.
    - A set of structured primitives to lexically compose concurrent tasks
      (e.g., `watching`, `every`, `par_or`).
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
The `call` primitive receives a function with the application logic in Atmos,
as follows:

- The `watching` command will execute its inner function during 5 seconds.
- The `every` loop will execute its inner function every second.
- After the `watching` terminates, the `call` returns back to Lua.

# Install

# Documentation

## Guide

### Tasks

The basic unit of execution of Atmos is a task, which receives a Lua function
as its body:

```
local T = task(function (<...>) -- task parameters
    <...>                       -- task body
end)
```

The `task` primitive returns a prototype, which further calls to `spawn` can
instantiate passing optional arguments:

```
local t1 = spawn(T, <...>)
local t2 = spawn(T, <...>)
```

### Events

The `await` primitive suspends a task until a matching event occurs:

```
local T = task (function (i)
    await 'X'
    print("task " .. i .. " awakes from X")
end)
```

The `emit` primitive broadcasts an event, which awakes all suspended tasks with
a matching `await`:

```
spawn(T, 1)
spawn(T, 2)
emit 'X'
    -- "task 1 awakes from X"
    -- "task 2 awakes from X"
```

### Environments

An environment is an external component that bridges input events from the real
world into an Atmos application.
These events can be timers, key presses, network packets, or other kind of
inputs, depending on the environment.

The environment is loaded through `require` and exports a `call` primitive that
emits events to the received body:

```
require "x"         -- environment "x" with events of type "X"

call(function ()
    await "X"       -- awakes when "x" emits "X"
    print("terminates after X")
end)
```

The `call` receives a body and passes control of the Lua application to the
environment.
The environment internally executes a continuous loop that polls external
events from the real world forwarded to Atmos through `emit` calls.
The body becomes an anonymous task that, when terminates, returns the control
from `call` to the Lua application.

The actual available events depend on the environment and should be documented
appropriately.

The standard distribution of Atmos provides the following environments:

- `atmos.env.clock`:
    A simple pure-Lua environment that uses `os.clock` to issue timer events.
- `atmos.env.sdl`:
    An environment that relies on [lua-sdl2][7] to provide window, mouse, key,
    and timer events.

### TODO

- scope
- abortion
- defer
- errors
- compounds
- scheduling

## Complete API

[1]: https://www.lua.org/
[2]: https://fsantanna.github.io/sc.html
[3]: https://en.wikipedia.org/wiki/Structured_concurrency
[4]: https://en.wikipedia.org/wiki/Event-driven_programming
[5]: https://www.ceu-lang.org/
[6]: https://en.wikipedia.org/wiki/Esterel
[7]: https://github.com/Tangent128/luasdl2
