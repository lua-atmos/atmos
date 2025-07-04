# API

[
    [Basic](#basic) |
    [Tasks](#tasks) |
    [Events](#events) |
    [Errors](#errors) |
    [Compounds](#compounds)
]

# Basic

[
    [call](#call--f) |
    [atmos.call](#atmoscall-steps-f) |
    [defer](#defer-f) |
]

## `call (..., f)`

Calls the given body as a task, passing control to an Atmos environment.

- Parameters:
    - `...`
        | extra arguments to the environment
    - `f: function`
        | task prototype as a function
- Returns:
    - `...`
        | return values from the task

The call returns when the given body terminates.

(This function is overridden by environments.)

## `atmos.call (steps, f)`

Calls the given body as a task, passing a list of step functions to execute in
a loop.

- Parameters:
    - `steps: {function}`
        | list of step functions
    - `f: function`
        | task prototype as a function
- Returns:
    - `...`
        | return values from the task

The call returns when the given body terminates.

(This function is only used internally by environments.)

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

# Tasks

[
    [task(f)](#task-inv-f) |
    [task()](#task-) |
    [tasks](#tasks-n) |
    [spawn(tsk)](#spawn-tsk-) |
    [spawn(f)](#spawn-inv-f-) |
    [spawn_in](#spawn_in-tsks-tsk-) |
    [toggle](#toggle-tsk-on)
]

## `task ([inv,] f)`

Creates a task from a given prototype.

- Parameters:
    - `inv: boolean = false`
        | if the task should become invisible in the hierarchy
    - `f: function`
        | task prototype as a function
- Returns:
    - `: task`
        | reference to task just created

An invisible task (`inv=true`) is substituted by its parent in the context
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

## `spawn ([inv,] f, ...)`

Spawns a function prototype as a task.

- Parameters:
    - `inv: boolean = false`
        | if the task should become invisible in the hierarchy
    - `f: function`
        | task to spawn as a function
    - `...`
        | extra arguments to pass to the function
- Returns:
    - `: task`
        | reference to task just spawned

A function spawn is equivalent to the call as follows:

```
spawn(task(inv,f), ...)
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

# Events

[
    [emit](#emit-e-) |
    [emit_in](#emit_in-to-) |
    [await](#await)
]

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

- `true`| matches any emit
- `false`| never matches an emit
- `x, ...`| `x==e` and all remaining arguments match the emit payloads
- `x: task`| `x==e`, modifying the await return to be the task return
- `x: tasks`| `e` matches any task in `x`
- `{ tag='_or_', ...}`|
- `{ tag='_and_', ...}`|
- `{ tag='clock', ...}`|
- `mt.__atmos`|
- `: function`| function receives `e,...` and returns if it matches, also
    modifying the await return

When the task terminates, its parent emits an event

# Errors

[
    [catch](#catch-err-f) |
    [throw](#throw-err-)
]

## `catch (err, f)`

## `throw (err, ...)`

# Compounds

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

## Parallels

### `par (...)`
### `par_and (...)`
### `par_or (...)`
