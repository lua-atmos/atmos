# API

[
    [Tasks](#tasks) |
    [Events](#events) |
    [Errors](#errors) |
    [Compounds](#compound-statements)
]

# Tasks

[
    [task](#task-inv-f) |
    [tasks](#tasks-n) |
    [spawn](#spawn-tsk-) |
    [spawn_in](#spawn_in-tsks-tsk-) |
    [toggle](#toggle-tsk-on) |
    [me](#me-)
]

## `task ([inv,] f)`

Creates a task from a given prototype.

- Parameters:
    - `inv: boolean = false`
        :: if the task should become invisible in the hierarchy
    - `f: function`
        :: task prototype as a Lua function
- Returns:
    - `: task`
        :: reference to task just created

An invisible task (`inv=true`) is substituted by its parent in the context
of [me](#me) and [emit](#emit) calls.

## `tasks (n)`

Creates a task pool.

- Parameters:
    - `n: number`
        :: maximum number instances
- Returns:
    - `: task`
        :: task pool

## `spawn (tsk, ...)`

Spawns a task.

- Parameters:
    - `tsk: task`
        :: task to spawn
    - `...`
        :: extra arguments to pass to the task prototype
- Returns:
    - `: task`
        :: reference to task just spawned

## `spawn ([inv,] f, ...)`

Spawns a function prototype as a task.

Expands to

```
spawn(task(inv,f), ...)
```

## `spawn_in (tsks, tsk, ...)`

Spawns a task in a task pool.

- Parameters:
    - `tsks: task pool`
        :: pool to spawn
    - `tsk: task`
        :: task to spawn
    - `...`
        :: extra arguments to pass to the task prototype
- Returns:
    - `: task`
        :: reference to task just spawned

## toggle (tsk, on)

Toggles a task on and off.

- Parameters:
    - `tsk: task`
        :: task to toggle
    - `on: boolean`
        :: toggle on (`true`) or off (`false`)
- Returns:
    - `nil`

## me ()

Returns a self-reference to the running task.

- Parameters:
    - none
- Returns:
    - `: task`
        :: reference to running task

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
        :: event to emit
    - `...`
        :: event payloads
- Returns
    - `nil`

### `emit_in (to, e, ...)`

Emits an event into a target.

- Parameters:
    - `to`
        :: emit target
    - `e`
        :: event to emit
    - `...`
        :: event payloads
- Returns
    - `nil`

The event target determines the scope of tasks affected by the emit.
The following values are accepted as target:

- `number`:: level above in the task hierarchy
    - `0`:: current task
    - `1`:: parent task
    - `2`:: parent of parent task
    - `n`:: (n times) parent of task
- `nil` or `'task'`:: equivalent to `0`
- `'global'`:: all top-level tasks
- `: task`:: the given task

## `await (...)`

Awaits an event pattern in the running task.

- Parameters:
    - `...`
        :: event pattern
- Returns:
    - `...`
        :: arguments of matching emit

The task awakes if an `emit(e,...)` matches the event pattern `...` as follows:

- `true`:: matches any emit
- `false`:: never matches an emit
- `x, ...`:: `x==e` and all remaining arguments match the emit payloads
- `x: task`:: `x==e`, modifying the await return to be the task return
- `x: tasks`:: `e` matches any task in `x`
- `{ tag='_or_', ...}`::
- `{ tag='_and_', ...}`::
- `{ tag='clock', ...}`::
- `mt.__atmos`::
- `: function`:: function receives `e,...` and returns if it matches, also
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
    [every](#every-f) |
    [watching](#watching-f) |
    [par](#par) |
    [par_and](#par_and) |
    [par_or](#par_or)
]

## `every (..., f)`

## `watching (..., f)`

## Parallels

### `par (...)`
### `par_and (...)`
### `par_or (...)`

## `toggle (evt, f)`

# Other

atmos.call (t)
atmos.close (task | tasks)
call
defer
