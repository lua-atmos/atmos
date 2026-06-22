# API

1. [Basic](#1-basic)
2. [Tasks](#2-tasks)
3. [Events](#3-events)
4. [Errors](#4-errors)
5. [Compounds](#5-compounds)
6. [Streams](#6-streams)
7. [Threads](#7-threads)
8. [Utilities](#8-utilities)

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
        | body as a function
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

Returns the status of the given task instance.

- Parameters:
    - `tsk: xtask`
        | task instance to check
- Returns:
    - `: string`
        | task status: 'running', 'suspended', 'normal', 'dead'

# 2. Tasks

[
    [task(f)](#task-f) |
    [xtask()](#xtask-) |
    [xtask(T)](#xtask-t) |
    [tasks](#tasks-n) |
    [abort](#abort-t) |
    [spawn](#spawn-t-) |
    [spawn_in](#spawn_in-tsks-t-) |
    [toggle](#toggle-tsk-on)
    [do_spawn](#do_spawn-f-) |
]

A *task prototype* (`task`) is an abstract, spawnable definition.

An *task instance* (`xtask`) is a spawned protoype with its own identity.

A *pool of task instances* (`tasks`) holds a set of spawned prototypes.

Task values render distinctly: `task: 0x...` (prototype), `xtask: 0x...`
(instance), `tasks: 0x...` (pool).

## `task (f)`

Creates a task prototype from a function.

- Parameters:
    - `f: function`
        | task body as a function
- Returns:
    - `: task`
        | task prototype

<!--
See also:
- [xtask](#xtask) to create a task instance from a prototype.
- [spawn](#spawn-t-) to create and start a task instance from a prototype.
- [spawn_in](#spawn_in-tsks-t-) to spawn an task instance into a pool.
-->

## `xtask ()`

Returns a self-reference to the running task instance.

- Parameters:
    - none
- Returns:
    - `: xtask`
        | running task instance

## `xtask (T)`

Creates a task instance from a prototype.

- Parameters:
    - `T: task`
        | task prototype
- Returns:
    - `: xtask`
        | task instance

## `tasks (n)`

Creates a task pool.

- Parameters:
    - `n: number`
        | maximum number of instances
- Returns:
    - `: tasks`
        | task pool

## `abort (t)`

Aborts a task instance or task pool.

- Parameters:
    - `t: xtask|tasks`
        | task instance or task pool to abort
- Returns:
    - `nil`

All nested tasks are also aborted.
All nested [deferred](#defer-f) blocks execute.

## `spawn (t, ...)`

Spawns a prototype as a task instance with its own identity.

- Parameters:
    - `t: task | xtask`
        | prototype to instantiate, or a pre-built instance to start
    - `...`
        | extra arguments to pass to the body
- Returns:
    - `: xtask`
        | task instance just spawned

## `spawn_in (tsks, t, ...)`

Spawns a task prototype into a pool.

- Parameters:
    - `tsks: tasks`
        | pool to spawn into
    - `t: task`
        | task prototype
    - `...`
        | extra arguments to pass to the body
- Returns:
    - `: xtask`
        | task instance just spawned (or `nil` if the pool is full)

## `toggle (tsk, on)`

Toggles a task instance (or pool) on and off.

- Parameters:
    - `tsk: xtask | tasks`
        | task instance or pool to toggle
    - `on: boolean`
        | toggle on (`true`) or off (`false`)
- Returns:
    - `nil`

## `do_spawn (f, ...)`

Spawns a raw function as an anonymous transparent nested task.

- Parameters:
    - `f: function`
        | inline task body
    - `...`
        | extra arguments to pass to the body
- Returns:
    - `: handle`
        | close-only lifetime handle

A transparent task has no identity, so the return is a close-only handle:
it cannot be awaited, toggled, or aborted, but it can bind the body to a
lexical block:

```
do
    local _ <close> = do_spawn(function () ... end)   -- aborted at block end
    ...
end
```

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
    - `e`
        | argument of matching emit

The task awakes when an `emit(e)` matches the given await pattern as follows:

| Group     | Pattern                             | matches        | returns  |
|-----------|-------------------------------------|----------------|----------|
| Boolean   | `true`                              | any event      | `e`      |
|           | `false`                             | never          | —        |
| Value     | `{tag=t,...}`                       | `X.gte(pat,e)` | `e`      |
|           | `x: any`                            | `X.is(e,x)`    | `e`      |
| Time      | `us: number`                        | timeout        | overrun  |
|           | `'clock'`                           | clock tick     | delta    |
| Tasks     | `t: xtask`                          | `t` ends       | `v,t`    |
|           | `T: task`                           | `T` ends       | `v,t`    |
|           | `{tag='tasks',mode='any',tasks=ts}` | any pool end   | `v,t,ts` |
|           | `{tag='tasks',mode='all',tasks=ts}` | all pool end   | `ts`     |
| Stream    | `s: stream`                         | `s` ends       | `v,t`    |
| Condition | `f: function`                       | `f(e)` truthy  | `e / res`|
|           | `{tag='until',x,...}`               | until all hold | `e / res`|
|           | `{tag='while',x,...}`               | while any fail | `e`      |
| Logical   | `{tag='not',x}`                     | not `p`        | `e`      |
|           | `{tag='and',...}`                   | all subs       | `e`      |
|           | `{tag='or',...}`                    | any sub        | `e`      |
| Meta      | `mt: meta`                          | via `__atmos`  | `e / res`|

Note that some patterns may modify the final result:

- Time: difference between the time elapsed and expected
- Tasks: task result, terminating task, and task pool
- Condition, Meta: function result (defaults to `e` if `true`)

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
    [loop_on](#loop_on--f) |
    [watching](#watching--f) |
    [toggle](#toggle-evt-f) |
    [par](#par-) |
    [par_all](#par_all-) |
    [par_any](#par_any-)
]

Compound statements combine tasks, awaits, and other primitive to provide
higher-level constructs.

## `loop_on (..., f)`

Executes the given body, in a loop, after every occurrence of the given event
pattern.

- Parameters:
    - `...`
        | event pattern
    - `f: function`
        | loop body as a function
- Returns:
    - never returns

A `loop_on` is equivalent to the code as follows:

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
par_any(function() return await(...) end, f)
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

### `par_all (...)`

Spawn the given bodies and terminate when all of them terminate.

- Parameters:
    - `...`
        | tasks to spawn as functions
- Returns:
    - `...`: return value of tasks (first per task)

### `par_any (...)`

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
    - `S.on (pat)`:
        stream of [await patterns](#await-pat)

- Combinators
    - `S.emitter(s,tgt,as)`:
        emit each value of `s` as `as` in target `tgt` (optional)
    - `S.par(...)`:
        merges all streams `...` into a single stream
    - `S.xpar(...)`:
        merges all streams of streams `...` into a single stream
    - `S.parany(...)`:
        like `par` but terminates when any of the streams `...` terminates
    - `S.xparany(...)`:
        like `parany` but terminates when any of the streams returned in `...`
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

# 8. Utilities

The module `atmos.x` provides value relations and helpers:

```
local X = require "atmos.x"
```

| function          | result      | meaning                                     |
|-------------------|-------------|---------------------------------------------|
| `X.gte(a,b)`      | `boolean`   | `a` is a supertype of/conforms to `b`       |
| `X.eq(a,b)`       | `boolean`   | deep equality: `gte(a,b) and gte(b,a)`      |
| `X.is(v,x)`       | `boolean`   | `v` is-a `x` (identity / type / tag / kind) |
| `X.xin(v,t)`      | `boolean`   | `v` is a member of `t` (as key or value)    |
| `X.cat(a,b)`      | `str/table` | `a .. b`, else a new table merging both     |
| `X.iter(t,...)`   | `iterator`  | generic-for over `t` (arity below)          |
| `X.tostring(v)`   | `string`    | stable rendering (table keys sorted)        |
| `X.print(...)`    | —           | `print` via `X.tostring`                    |
| `X.copy(v)`       | `value`     | deep copy                                   |

- TODO
    - `X.gte`:  `a == b`, same types/metas, subtags, subsumes fields
    - `X.is`:   type name, proto `task` / instance `xtask` / pool `tasks`,
                table tag
    - `X.iter`: arity by source
        - 1: `number` / `(n,m)` / `nil`
        - 2: `table` / `__pairs`
        - n: `function` / `__call`
