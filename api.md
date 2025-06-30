# API

## Tasks

- `task (f, inv)`
    - `f: function`
        :: task prototype as a Lua function
    - `inv: boolean`
        :: if task is invisible in the hierarchy

An invisible task is substituted by its parent in the context of [me](#TODO)
and [emit](#TODO) calls.

- `tasks (n)`
    - `n: number`
        :: maximum number instances

<!--
spawn (nested, t, ...)
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
