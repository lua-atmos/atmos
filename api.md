# API

[
    [Tasks](#tasks) |
    [Events](#events) |
    [Errors](#errors) |
    [Compounds](#compound-statements)
]

## Tasks

[
    [task](#TODO) |
    [tasks](#TODO) |
    [spawn](#TODO) |
    [spawn_in](#TODO)
]

<a name="f-task"\>

### `task ([inv,] f)`

Creates a task from a given prototype.

- Parameters:
    - `inv: boolean = false`
        :: if the task should become invisible in the hierarchy
    - `f: function`
        :: task prototype as a Lua function
- Returns:
    - task

An invisible task (`inv=true`) is substituted by its parent in the context
of [me](#me) and [emit](#emit) calls.

### `tasks (n)`

Creates a task pool.

- Parameters:
    - `n: number`
        :: maximum number instances
- Returns:
    - task pool

### `spawn (tsk, ...)`

Spawns a task.

- Parameters:
    - `tsk: task`
        :: task to spawn
    - `...`
        :: extra arguments to pass to the task prototype

#### `spawn ([inv,] f, ...)`

Spawns a function prototype as a task.

Expands to

```
spawn(task(inv,f), ...)
```

### `spawn_in (tsks, tsk, ...)`

Spawns a task in a task pool.

- Parameters:
    - `tsks: task pool`
        :: pool to spawn
    - `tsk: task`
        :: task to spawn
    - `...`
        :: extra arguments to pass to the task prototype

# Events



toggle
me

- Emit

emit (e, ...)
emit_in (to, e, ...)

- Await

await
clock
_and_
_or_

## Errors

catch
throw

## Compounds

every
par
par_and
par_or
toggle
watching

- Other

atmos.call (t)
atmos.close (task | tasks)
call
defer
