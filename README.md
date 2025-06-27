# lua-atmos (v0.1)

[
    [About](#about)                 |
    [Hello World!](#hello-world)    |
    [Install](#install)             |
    [Guide](#guide)                 |
    [API](#api)
]

# About

Atmos is a programming library for [Lua][1] that reconciles *[Structured
Concurrency][2]* with *[Event-Driven Programming][3]*, extending classical
structured programming with two main functionalities:

- Structured Deterministic Concurrency:
    - The `task` primitive with deterministic scheduling provides predictable
      behavior and supports safe abortion.
    - Structured primitives compose concurrent tasks with lexical scope (e.g.,
      `watching`, `every`, `par_or`).
    - The `tasks` container primitive holds dynamic tasks, which automatically
      releases them as they terminate.
- Event Signaling Mechanisms:
    - The `await` primitive suspends a task and wait for events.
    - The `emit` primitive signal events and awake awaiting tasks.

Atmos is inspired by [synchronous programming languages][4], such as [Ceu][5]
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

# Guide

[
    [Tasks](#tasks) |
    [Events](#events) |
    [Scheduling](#deterministic-scheduling) |
    [Environments](#environments) |
    [Task Hierarchy](#lexical-task-hierarchy) |
    [Errors](#errors) |
    [Compound Statements](#compound-statements)
]

## Tasks

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

If a task prototype is spawned only once, its body can be passed directly to
`spawn`:

```
local t = spawn(function ()
    <...>   -- task body
end)
```

## Events

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

## Deterministic Scheduling

Tasks are based on Lua coroutines, and follows its run-to-completion semantics:
When a task spawns or awakes, it takes full control of the application and
executes until it awaits or terminates.

Consider the code that spawns two tasks and await the same event `X` as
follows:

```
print "1"
spawn(function ()
    print "a1"
    await 'X'
    print "a2"
end)
print "2"
spawn(function ()
    print "b1"
    await 'X'
    print "b2"
end)
print "3"
emit 'X'
print "4"

-- Output:
-- 1
-- a1
-- 2
-- b1
-- 3
-- a2
-- b2
-- 4
```

In the example, the scheduling behaves as follows:

- Main application prints `1` and spawns the first task.
- The first task takes control, prints `a1`, and suspends, returning the
  control back to the main application.
- The main application print `2` and spawns the second task.
- The second task starts, prints `b1`, and suspends.
- The main application prints `3`, and broadcasts `X`.
- The first task awakes, prints `a2`, and suspends.
- The second task awakes, prints `b2`, and suspends.
- The main application prints `4`.

## Environments

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

## Lexical Task Hierarchy

Tasks form a hierarchy based on the textual position in which they are spawned.
Therefore, the lexical structure of the program determines the lifetime of
tasks, which helps to reason about its control flow:

```
spawn(function ()
    spawn(function ()
        await 'Y'   -- never awakes after 'X' occurs
    end)
    await 'X'       -- aborts the whole task hierarchy
end)
emit 'X'
emit 'Y'
```

The same rule extends to explicit blocks with the help of Lua `<close>`
declarations:

```
spawn(function ()
    <...>   -- some logic before the block
    do
        local _ <close> = spawn(function ()
            await 'Y'   -- never awakes after 'X' occurs
        end)
        local _ <close> = spawn(function ()
            await 'Z'   -- never awakes after 'X' occurs
        end)
        await 'X'       -- aborts the whole task hierarchy
    end
    <...>   -- some logic after the block
end)
emit 'X'
emit 'Y'
```

In the example, we enclose particular tasks we want to live only within the
explicit block.
When the event `X` occurs, the block goes out and automatically aborts all
attached spawned tasks.

Since Atmos is a pure-Lua library, note that the annotation `local _ <close> =`
is necessary when bounding a `spawn` to a block.
We can omit this annotation only when we want to attach the `spawn` to its
enclosing task.

### Deferred Statements

A task can register deferred functions to execute when they terminate or
abort within a task hierarchy:

```
call(function ()
    spawn(function ()
        local _ <close> = defer(function ()
            print "nested task aborted"
        end)
        await(false) -- never awakes
    end)
end)
-- "nested task aborted"
```

The nested spawned task never awakes, but executes its `defer` clause when
its enclosing hierarchy terminates.

Note that the annotation `local _ <close> =` is also required for deferred
statements.

Deferred statements also attach to the scope of explicit blocks:

```
print "1"
do
    print "2"
    local _ <close> = defer(function ()
        print "3"
    end)
    print "4"
end
print "5"

-- Output:
-- 1
-- 2
-- 4
-- 3
-- 5
```

## Errors

Atmos provides `throw` and `catch` primitives to handle errors, taking the task
hierarchy into consideration:

```
function T ()
    spawn (function ()
        throw 'X'
    end)
end

spawn(function ()
    local ok, err = catch('X', function ()
        spawn(T)
    end)
    print(ok, err)
end)

-- "false, X"
```

In the example, we spawn a task that catches errors of type `X`.
Then we spawn a named task, which spawns an anonymous task, which finally
throws an error `X`.
The error propagates up in the task hierarchy until it is caught, returning
`false` and the error `X`.

`TODO: stack trace`

## Compound Statements

`TODO`

# API

`TODO`

[1]: https://www.lua.org/
[2]: https://en.wikipedia.org/wiki/Structured_concurrency
[3]: https://en.wikipedia.org/wiki/Event-driven_programming
[4]: https://fsantanna.github.io/sc.html
[5]: http://www.ceu-lang.org/
[6]: https://en.wikipedia.org/wiki/Esterel
[7]: https://github.com/Tangent128/luasdl2
