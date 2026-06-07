# API

1. [Basic](#1-basic)
2. [Tasks](#2-tasks)
3. [Events](#3-events)
4. [Errors](#4-errors)
5. [Compounds](#5-compounds)
6. [Streams](#6-streams)
7. [Threads](#7-threads)

# 1. Basic

[
    [loop](#loop-f) |
    [defer](#defer-f) |
    [atmos.env](#atmosenv-e) |
    [atmos.status](#atmosstatus-tsk)
]

## `loop (f)`

Calls the given body as a task, passing control to Atmos.

- Parameters:
    - `f: function`
        | task prototype as a function
- Returns:
    - `...`
        | return values from the task

The loop returns when the given body terminates.

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

Registers an environment table with Atmos.

- Parameters:
    - `e: { ... }`
        | environment table with callback functions
        - `step: function`
            | called by [loop](#loop-f) continually until the body terminates
        - `quit: function`
            | called by [loop](#loop-f) when the body terminates (or on any error)
        - `mode: table`
            | `{ primary=true, secondary=true }` for multi-env support

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
    [abort](#abort-t) |
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

## `abort (t)`

Aborts a task or task pool.

- Parameters:
    - `t: task|tasks`
        | task or task pool to abort
- Returns:
    - `nil`

All nested tasks are also aborted.
All nested [deferred](#defer-f) blocks execute.

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
    [await](#await-pat)
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

## `await (pat)`

Awaits an event pattern in the running task.

- Parameters:
    - `pat`
        | event pattern
- Returns:
    - `...`
        | arguments of matching emit

The task awakes when an `emit(e)` matches the given await pattern as follows:

- `true`        | matches any event
- `false`       | never matches
- `c: clock`    | when [clock](#TODO) `c` expires
- `f: function` | when `f(e,...)` is truthy, returning its results
- `t: task`     | when `t` terminates; returns `v,t`, where `v` is the
                  task return value
- `tasks`       | when any or all tasks in a pool terminate
    - `{ tag='tasks', mode='any', tasks=ts }`: returns `v,t,ts`
        (`t`: terminated task, `v`: its return value)
    - `{ tag='tasks', mode='all', tasks=ts }`: returns `ts`
- `logical`     | composition of sub-patterns
    - `{ tag='not', x }`:  matches any event that does not match `x`
    - `{ tag='and', ...}`: when all `...` match (in any order)
    - `{ tag='or', ...}`:  when any `...` matches
- `until|while` | re-awaits a pattern until/while predicates hold
    - `{ tag='until', x, ... }`: matches `x`, then applies each `fi` in `...` to
      the event; awakes only when all are non-falsy; returns the event or last
      non-true value
    - `{ tag='while', x, ... }`: analogous to `until`; returns the event when any
      is falsy.
- `x: meta`     | custom `v=__atmos(x,e,...)` metamethod
    - `v = nil`:    use standard handler
    - `v = false`:  no match
    - `v = ...`:    matches, replacing the results
- `{ tag=t, ... }` | when `_is_(e.tag,t)` and `_is_(e[k],v)` for every field
- `x: any`      | when `_is_(e,x)`

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
par_or(function() return await(...) end, f)
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
    - `...`: return value of tasks (first per task)

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

# 7. Threads

## `thread (f)`

Spawns a function to execute in an OS thread and awaits its termination.

- Parameters:
    - `f: function`
        | function to execute in a separate thread
- Returns:
    - `...`
        | function return values

The function receives copies of its upvalues, but cannot access Atmos
primitives (`await`, `emit`, `spawn`).
