# Guide

[
    [Tasks](#tasks) |
    [Events](#events) |
    [Scheduling](#deterministic-scheduling) |
    [Environments](#environments) |
    [Hierarchy](#lexical-task-hierarchy) |
    [Pools](#task-pools) |
    [Errors](#errors) |
    [Compounds](#compound-statements)
]

# Tasks

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

## Public Data

A task is a Lua table, and can hold public data fields as usual.
It is also possible to self refer to the running task with a call to `task()`:

```
function T ()
    task().v = 10
end
local t = spawn(T)
print(t.v)  -- 10
```

# Events

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

## Task Toggling

A task can be toggled off (and back to on) to remain alive but unresponsive
(and back to responsive) to upcoming events:

```
local t = spawn (function ()
    await 'X'
    print "awakes from X"
end)
toggle(t, false)
emit 'X'    -- ignored
toggle(t, true)
emit 'X'    -- awakes
```

# Deterministic Scheduling

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

# Environments

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
    An environment that relies on
    [lua-sdl2](https://github.com/Tangent128/luasdl2) to provide window, mouse,
    key, and timer events.

# Lexical Task Hierarchy

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
When the event `X` occurs, the block goes out of scope and automatically aborts
all attached spawned tasks.

Since Atmos is a pure-Lua library, note that the annotation `local _ <close> =`
is necessary when bounding a `spawn` to a block.
We can omit this annotation only when we want to attach the `spawn` to its
enclosing task.

## Deferred Statements

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

# Task Pools

A task pool allows for multiple tasks to share a parent container in the task
hierarchy.
When the pool goes out of scope, all attached tasks are aborted.
When a task terminates, it is automatically removed from the pool.

```
function T (id, ms)
    task().id = id
    print('start', id, ms)
    await(clock{ms=ms})
    print('stop', id, ms)
end

do
    local ts <close> = tasks()
    for i=1, 10 do
        spawn_in(ts, T, i, math.random(500,1500))
    end
    await(clock{s=1})
end
```

In the example, we first create a pool `ts` with the `tasks` primitive.
Then we use `spawn_in` to spawn and attach 10 tasks into the pool.
Each task sleeps between `500ms` and `1500ms` before terminating.
After `1s`, the `ts` block goes out of scope, aborting all tasks that did not
complete.

Task pools provide a `pairs` iterator to traverse currently attached tasks:

```
for _,t in pairs(ts) do
    print(t.id)
end
```

If we include this loop after the `await(clock{s=1})` in the previous example,
it will print the task ids that did not awake.

# Errors

Atmos provides `throw` and `catch` primitives to handle errors, which take in
consideration task hierarchy, i.e., a parent task catches errors from child
tasks.

```
function T ()
    spawn (function ()
        await 'X'
        throw 'Y'
    end)
    await(false)
end

spawn(function ()
    local ok, err = catch('Y', function ()
        spawn(T)
        await(false)
    end)
    print(ok, err)
end)

emit 'X'

-- "false, Y"
```

In the example, we spawn a parent task that catches errors of type `Y`.
Then we spawn a named task `T`, which spawns an anonymous task, which awaits
`X` to finally throw `Y`.
Outside the task hierarchy, we `emit X`, which only awakes the nested task.
Nevertheless, the error propagates up in the task hierarchy until it is caught
by the top-level task, returning `false` and the error `Y`.

## Bidimensional Stack Traces

An error trace may cross multiple tasks from a series of emits and awaits,
e.g.: an `emit` in one task awakes an `await` in another task, which may `emit`
and match an `await` in a third task.
However, *cross-task traces* do not inform how each task in the trace started
and reached its `emit`, i.e. each of the *intra-task* traces, which is as much
as insightful to understand the errors.

Atmos provides bidimensional stack traces, which include cross-task and
intra-task traces.

In the next example, we spawn 3 tasks in `ts`, and then `emit` an event
targeting the task with `id=2`.
Only this task awakes and generates an uncaught error:

```
function T (id)
    await('X', id)
    throw 'error'
end

local ts <close> = tasks()
spawn_in(ts, T, 1)
spawn_in(ts, T, 2)
spawn_in(ts, T, 3)

emit('X', 2)
```

The stack trace identifies that the task lives in `ts` in line 6 and spawns in
line 8, before throwing the error in line 3:

```
==> ERROR:
 |  x.lua:11 (emit)
 v  x.lua:3 (throw) <- x.lua:8 (task) <- x.lua:6 (tasks)
==> error
```

# Compound Statements

Atmos provides many compound statements built on top of tasks and awaits as
follows:

- The `every` statement expands to a loop that awaits its first argument at the
  beginning of each iteration:

```
every(clock{s=1}, function ()
    print "1 second elapses"    -- prints this message every second
end)
```

- The `watching` statement awaits the given body to terminate, or aborts if its
  first argument occurs:

```
watching(clock{s=1}, function ()
    await 'X'
    print "X happens before 1s" -- prints this message unless 1 second elapses
end)
```

- The `par`, `par_and`, `par_or` statements spawn multiple bodies and rejoin
  after their bodies terminates as follows: `par` never rejoins, `par_and`
  rejoins after all terminate, `par_or` rejoins after any terminates.

```
par_and(function ()
    await 'X'
end, function ()
    await 'Y'
end, function ()
    await 'Z'
end)
print "X, Y, and Z occurred"
```

- The `toggle` statement awaits the given body to terminate, while also
  observing its first argument as a boolean event:
  When receiving `false`, the body toggles off.
  When receiving `true`, the body toggles on.

```
toggle('X', function ()
    every(clock{s=1}, function ()
        print "1s elapses"
    end)
end)
emit('X', false)    -- body above toggles off
<...>
emit('X', true)     -- body above toggles on
<...>
```

