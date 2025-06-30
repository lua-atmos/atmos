# API

## Tasks

### `task (inv, f)`

Creates a task from a given prototype.

- Parameters:
    - `inv: boolean = false`
        :: if task is invisible in the hierarchy
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
        :: extra arguments passed to the task prototype

#### `spawn (inv, f, ...)`

Expands to

```
spawn(task(inv,f), ...)
```

- Parameters:
    - `inv: boolean = false`
        :: if task is invisible in the hierarchy
    - `tsk: task|function`
        :: task or function prototype to spawn
    - `...`
        :: extra arguments passed to the task prototype


- Returns 
spawn_in (up, t, ...)
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

- Errors

catch
throw

- Compounds

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
-->
