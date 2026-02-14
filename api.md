# API

1. [Basic](#1-basic)
2. [Tasks](#2-tasks)
3. [Events](#3-events)
4. [Errors](#4-errors)
5. [Compounds](#5-compounds)
6. [Streams](#6-streams)

# 1. Basic

[
    [call](#call-f) |
    [defer](#defer-f) |
    [atmos.env](#atmosenv-e) |
    [atmos.status](#atmosstatus-tsk)
]

## `call (f)`

Calls the given body as a task, passing control to Atmos.

- Parameters:
    - `f: function`
        | task prototype as a function
- Returns:
    - `...`
        | return values from the task

The call returns when the given body terminates.

## `defer (f)`

Executes the given function when the enclosing scope terminates.

- Parameters:
    - `f: function`
        | function to execute
- Returns:
    - `: table`
        | special table that requires a `<close>` assignment

A defer requires a `<close>` assignment in the scope of interest:

```
do
    local _ <close> = defer(<...>)
    <...>
end
```

## `atmos.env (e)`

Registers an environment that bridges external events into an Atmos application.

An environment provides the control loop that drives a `call` body, polling
external events (timers, key presses, network packets, etc.) and forwarding
them to Atmos through `emit` calls.

- Parameters:
    - `e: { ... }`
        | environment table with callback functions and state fields
        - `step: function`
            | called by [call](#call-f) continually in a loop until the body
              terminates or `step` returns `true`
        - `loop: function`
            | replaces the default [call](#call-f) loop entirely
        - `stop: function`
            | called when the [call](#call-f) body terminates normally, before
              cleanup
        - `close: function`
            | called after the [call](#call-f) body terminates (or on any
              error), for resource cleanup
        - `now: number`
            | elapsed milliseconds since the environment was loaded

An environment must provide either `step` or `loop` (not both):

- **`step`-based**: The default [call](#call-f) loop calls `step()`
  repeatedly. Each call should poll for external events and `emit` them.
  Returning `true` from `step` signals the loop to exit.

- **`loop`-based**: The `loop()` function replaces the default loop entirely.
  This is used when an external framework provides its own main loop (e.g.,
  GUI toolkits). The environment must call `stop()` from within the loop to
  signal termination.

### Lifecycle

When [call](#call-f) executes with a registered environment, the lifecycle
proceeds as follows:

```
call(body)
 1. spawn body as a task
 2. enter loop:
    - if `loop` is set:  loop()
    - if `step` is set:  while step()~=true and body is alive
 3. body terminates:
    - stop()   -- environment-specific shutdown (e.g., exit GUI loop)
 4. after body terminates:
    - close()  -- resource cleanup (e.g., quit SDL)
    - run.close()  -- abort all remaining tasks
```

### Creating an Environment

An environment is a Lua module that calls `atmos.env(e)` during `require`.
It returns a module table with any additional API functions or state:

```
local atmos = require "atmos"
local M = { now = 0 }

function M.step ()
    -- poll for external events
    -- emit('clock', dt, now)
    -- emit(other_events)
    -- return true to signal exit
end

function M.close ()
    -- cleanup resources
end

atmos.env(M)    -- M has `step` and `close` fields
return M
```

(This function is only used internally by environments.)

## `atmos.status (tsk)`

Returns the status of the given task.

- Parameters:
    - `tsk: task`
        | task to check
- Returns:
    - `: string`
        | task status: 'running', 'suspended', 'normal', 'dead'

# 2. Tasks

[
    [task(f)](#task-tra-f) |
    [task()](#task-) |
    [tasks](#tasks-n) |
    [spawn(tsk)](#spawn-tsk-) |
    [spawn(f)](#spawn-tra-f-) |
    [spawn_in](#spawn_in-tsks-tsk-) |
    [toggle](#toggle-tsk-on)
]

## `task ([tra,] f)`

Creates a task from a given prototype.

- Parameters:
    - `tra: boolean = false`
        | if the task should become transparent in the hierarchy
    - `f: function`
        | task prototype as a function
- Returns:
    - `: task`
        | reference to task just created

A transparent task (`tra=true`) is substituted by its parent in the context
of [task()](#task-) and [emit](#emit) calls.

## `task ()`

Returns a self-reference to the running task.

- Parameters:
    - none
- Returns:
    - `: task`
        | reference to running task

## `tasks (n)`

Creates a task pool.

- Parameters:
    - `n: number`
        | maximum number instances
- Returns:
    - `: task`
        | task pool

## `spawn (tsk, ...)`

Spawns a task.

- Parameters:
    - `tsk: task`
        | task to spawn
    - `...`
        | extra arguments to pass to the task prototype
- Returns:
    - `: task`
        | reference to task just spawned

## `spawn ([tra,] f, ...)`

Spawns a function prototype as a task.

- Parameters:
    - `tra: boolean = false`
        | if the task should become transparent in the hierarchy
    - `f: function`
        | task to spawn as a function
    - `...`
        | extra arguments to pass to the function
- Returns:
    - `: task`
        | reference to task just spawned

A function spawn is equivalent to the call as follows:

```
spawn(task(tra,f), ...)
```

## `spawn_in (tsks, tsk, ...)`

Spawns a task in a task pool.

- Parameters:
    - `tsks: task pool`
        | pool to spawn
    - `tsk: task`
        | task to spawn
    - `...`
        | extra arguments to pass to the task prototype
- Returns:
    - `: task`
        | reference to task just spawned

## toggle (tsk, on)

Toggles a task on and off.

- Parameters:
    - `tsk: task`
        | task to toggle
    - `on: boolean`
        | toggle on (`true`) or off (`false`)
- Returns:
    - `nil`

# 3. Events

[
    [emit](#emit-e-) |
    [emit_in](#emit_in-to-) |
    [await](#await)
]

`TODO: event tag/payload`

### `emit (e, ...)`

Emits an event.

- Parameters:
    - `e`
        | event to emit
    - `...`
        | event payloads
- Returns
    - `nil`

### `emit_in (to, e, ...)`

Emits an event into a target.

- Parameters:
    - `to`
        | emit target
    - `e`
        | event to emit
    - `...`
        | event payloads
- Returns
    - `nil`

The event target determines the scope of tasks affected by the emit.
The following values are accepted as target:

- `number`| level above in the task hierarchy
    - `0`| current task
    - `1`| parent task
    - `2`| parent of parent task
    - `n`| (n times) parent of task
- `nil` or `'task'`| equivalent to `0`
- `'global'`| all top-level tasks
- `: task`| the given task

## `await (...)`

Awaits an event pattern in the running task.

- Parameters:
    - `...`
        | event pattern
- Returns:
    - `...`
        | arguments of matching emit

The task awakes if an `emit(e,...)` matches the event pattern `...` as follows:

- `true` | matches any emit
- `false` | never matches an emit
- `x, ...` | `x==e` and all remaining arguments match the emit payloads
- `x: task` | `x==e`, modifying the await return to be the task return
- `x: tasks` | `e` matches any task in `x`
- `{ tag='clock', h=?, min=?, s=?, ms=? }` | TODO
- `{ tag='_and_', ...}` | `e` matches all the patterns in `...`
- `{ tag='_or_', ...}` | `e` matches any of the patterns in `...`
- `mt.__atmos` | TODO
- `: function` | function receives `e,...` and returns if it matches, also
    modifying the await return

### `clock { ... }`

Expands to `{ tag='clock', ... }`.

### `_and_ (...)`

Expands to `{ tag='_and_', ... }`.

### `_or_ (...)`

Expands to `{ tag='_or_', ... }`.

# 4. Errors

[
    [catch](#catch-err-f) |
    [throw](#throw-err-)
]

## `catch (err, f)`

`TODO`

- true, false, function
- list `is`

## `throw (err, ...)`

`TODO`

# 5. Compounds

[
    [every](#every--f) |
    [watching](#watching--f) |
    [toggle](#toggle-evt-f) |
    [par](#par-) |
    [par_and](#par_and-) |
    [par_or](#par_or-)
]

Compound statements combine tasks, awaits, and other primitive to provide
higher-level constructs.

## `every (..., f)`

Executes the given body, in a loop, after every occurrence of the given event
pattern.

- Parameters:
    - `...`
        | event pattern
    - `f: function`
        | loop body as a function
- Returns:
    - never returns

An `every` is equivalent to the code as follows:

```
while true do
    f(await(...))
end
```

## `watching (..., f)`

Executes the given body until it terminates or until the given event pattern
occurs.

- Parameters:
    - `...`
        | event pattern
    - `f: function`
        | body as a function
- Returns:
    - `...`
        | return values of the body or matching event

A `watching` is equivalent to the call as follows:

```
await(_or_({...}, spawn(f)))
```

## `toggle (evt, f)`

Executes the given body until it terminates.
Meanwhile, toggles it on and off based on occurrences of the given event.

- Parameters:
    - `evt`
        | boolean event
    - `f: function`
        | body as a function
- Returns:
    - `...`
        | return values of the body

## 5.1. Parallels

### `par (...)`

Spawn the given bodies and never terminates.

- Parameters:
    - `...`
        | tasks to spawn as functions
- Returns:
    - never returns

### `par_and (...)`

Spawn the given bodies and terminate when all of them terminate.

- Parameters:
    - `...`
        | tasks to spawn as functions
- Returns:
    - `: table`: combined returns of the tasks

### `par_or (...)`

Spawn the given bodies and terminate when any of them terminates.

- Parameters:
    - `...`
        | tasks to spawn as functions
- Returns:
    - `...`: return values of the terminating task

# 6. Streams

Basic documentation:

- https://github.com/lua-atmos/f-streams/tree/v0.2

Extensions:

```
local S = require "atmos.streams"
```

- Sources
    - `S.fr_await(evt)`:
        stream of events `evt`
    - `S.fr_await(T)`:
        stream of tasks `T`
    - `S.from(clk)`:
        stream of periodic `clk` events

- Combinators
    - `S.emitter(s,tgt,as)`:
        emit each value of `s` as `as` in target `tgt` (optional)
    - `S.par(...)`:
        merges all streams `...` into a single stream
    - `S.xpar(...)`:
        merges all streams of streams `...` into a single stream
    - `S.paror(...)`:
        like `par` but terminates when any of the streams `...` terminates
    - `S.xparor(...)`:
        like `paror` but terminates when any of the streams returned in `...`
        terminates

`TODO: parand / xparand`
