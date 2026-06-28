# Plan: emit-target counts transparent tasks (target-bug)

## Status

- [x] Diagnose root cause
- [x] Add failing test (`tst/tasks.lua`) — confirmed red
- [x] Fix `fto` to skip transparent tasks (and pools)
- [x] Run `tst/all.lua` — all green

## Summary

`emit @N` (numeric target) must be *identity-based*:
it should skip transparent tasks, like task identity (`_me_`) already
does.
Today `fto` counts transparent tasks during its upward climb, so the
level needed changes depending on whether an intermediate body was a
`spawn {}` (transparent) or `do {}` (none).

## Root cause

`fto` in `atmos/run.lua`, numeric-`to` branch:

```lua
elseif type(to) == 'number' then
    local n = tonumber(to)
    to = me or TASKS        -- me = M.me(false): _me_ skipped transparent
    while n > 0 do
        to = to._.up        -- plain hop : never checks `_.tra`
        assertn(3, to~=nil, "invalid emit : invalid target")
        n = n - 1
    end
```

The `tra` flag is honored only by `_me_` (start anchor).
The climb hops `_.up` blindly, so a transparent `spawn {}` block
(`do_spawn` -> `M.spawn(..., tra=true)`) is counted like a real task.

For `emit_in(2, ...)` from a real `Inner` under a transparent block:

| step  | task      | tra?  | counted?           |
|-------|-----------|-------|--------------------|
| start | Inner     | false | (anchor)           |
| n -> 1| SpawnBlk  | true  | yes (should skip)  |
| n -> 0| Mid       | false | yes                |

## Fix

Skip transparent tasks and pools at every hop, mirroring `_me_`.
Candidate:

```lua
elseif type(to) == 'number' then
    local n = tonumber(to)
    to = me or TASKS
    while n > 0 do
        to = to._.up
        assertn(3, to~=nil, "invalid emit : invalid target")
        -- identity-based: transparent tasks and pools are invisible
        while (to~=TASKS) and
              ((getmetatable(to)==meta_tasks) or to._.tra)
        do
            to = to._.up
            assertn(3, to~=nil, "invalid emit : invalid target")
        end
        n = n - 1
    end
```

Resolved: skip transparent tasks only, NOT pools.
`streams.lua` (`emit_in(3, ...)`) calibrates numeric levels by
*counting* pools (`spawn_in`), so skipping pools breaks `S.par`
(`tst/streams.lua` "par 1"). The bug is solely about transparent
`spawn {}` blocks; `fto` and `_me_` diverge on pools by design.

Final skip condition (numeric branch):

```lua
while (to~=TASKS) and to._.tra do
    to = to._.up
    assertn(3, to~=nil, "invalid emit : invalid target")
end
```

## Adapted failing test

Raw-Lua form (mirrors the `.atm` test in the atmos compiler repo).
Add to `tst/tasks.lua` (or `tst/par.lua`):

```lua
do
    print("Testing...", "emit target : transparent spawn-block")
    local Inner = task(function ()
        await('go')
        emit_in(2, 'h')
    end)
    -- Main wrapper (mirrors the .atm top-level `func` task)
    spawn(task(function ()
        spawn(task(function ()        -- Mid
            do_spawn(function ()      -- transparent spawn-block
                await(Inner)
            end)
            await(false)
        end))
        par_any(
            function () await('h'); out('ok') end,
            function () emit('go') end
        )
    end))
    assertx(out(), "ok\n")
    atmos.stop()
end
```

Tree: `Inner -> [SpawnBlk tra] -> Mid -> Main(par)`.

- Expected (fixed): `emit_in(2)` skips `SpawnBlk`, targets `Main`,
  reaches `par` -> `"ok\n"`.
- Current  (buggy): counts `SpawnBlk`, targets `Mid`, misses -> `""`.

## Regression checks

- `emit @N` with non-transparent tasks unchanged (e.g. `spawn T()`).
- Emitting *from inside* a transparent block still works (start anchor
  already skips it).
- `tst/par.lua`, `tst/task.lua`, `tst/tasks.lua` still green.
