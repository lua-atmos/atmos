# Plan: tail-calls

## Goal

Prevent tail call optimization from eliminating stack frames
needed by `debug.getinfo(2)` in the Lua runtime (`lua-atmos`).

User code should be free to use tail calls — they are the
idiomatic style in Lua and the runtime must support them.

## Context

- The atmos-lang compiler already protects against this via
  `atm_func` wrapping and `is_stmt` codegen guards.
- The plain Lua runtime has NO protection: user functions passed
  to `M.spawn` become coroutine entry points. A tail call from
  there can eliminate the frame, causing `debug.getinfo(2)` to
  return nil and crash.
- `M.loop` and `M.start` already have a manual workaround:
  `return (function (...) return ... end)(body(...))`.
- The runtime only uses one return value (`t.ret = err`), so
  single-return is sufficient, but multi-return is cleaner.

## Vulnerability

Framework functions that always dereference `debug.getinfo(2)`:
- `M.throw` (line 221)
- `M.tasks` (line 398)
- `M.emit` (line 796 — only on error path)

Unprotected spawn sites (user functions become coroutine entry):
- `M.toggle` (line 812)
- `M.par` (line 863)
- `M.par_or` (line 874)
- `M.par_and` (line 885)
- `M.watching` (line 895)

## Analysis: runtime internal tail calls

The runtime has `return M.await(...)` in `M.toggle`,
`M.par_or`, `M.par_and`, and `M.watching`. These are NOT
proper tail calls because each function has `<close>` variables
in scope:

- `M.toggle:812-813` — `t <close>`, `_ <close>`
- `M.par:860` — `ts <close>`
- `M.par_or:871` — `ts <close>`
- `M.par_and:882` — `ts <close>`
- `M.watching:895` — `spw <close>`

In Lua 5.4, `return f()` with `<close>` variables is not a
proper tail call — close handlers must run after the return
value is computed. The stack frame is preserved.

Conclusion: no fix needed for runtime internal calls.

## Fix

Use `local _no_tco_ <close> = nil` to prevent TCO.

In Lua 5.4, `nil` is valid for `<close>` (no-op on close).
The compiler sees the to-be-closed annotation at compile time
and generates `OP_CLOSE` + `OP_RETURN` instead of
`OP_TAILCALL`, regardless of the runtime value.

Advantages over `return (f(...))`:
- preserves multiple return values
- explicit about intent (variable name documents why)
- searchable (`_no_tco_`)

### M.task — wrap all coroutine entries

```lua
function M.task (dbg, tra, f)
    assertn(3, type(f)=='function', ...)
    local f = function (...)
        local _no_tco_ <close> = nil
        return f(...)
    end
    ...
end
```

### M.loop / M.start — simplify existing workaround

Before:
```lua
local body = function (...)
    return (function (...) return ... end)(body(...))
end
```

After (redundant — M.task already wraps, so remove entirely):
```lua
-- (deleted)
```

## Tasks

### lua-atmos (runtime)
- [ ] Apply `_no_tco_ <close> = nil` wrapping in `M.task`
- [ ] Remove redundant wrapping from `M.loop`
- [ ] Remove redundant wrapping from `M.start`
- [ ] Add tests with tail calls to `debug.getinfo`-using
      functions (promote tail calls as idiomatic Lua):
      - `return tasks()` from a spawned function
      - `return throw(...)` from a spawned function
      - `return emit(...)` from a spawned function
- [ ] Run tests to verify

### atmos-lang (compiler)
- [ ] Remove `is_stmt` tail call guards from `src/coder.lua:21`
      - throw, spawn_in, emit, emit_in no longer need
        special treatment — the runtime now protects all
        coroutine entries
- [ ] Run atmos-lang tests to verify

## References

- atmos-lang "tasks 25: former bug - tail call"
- atmos-lang compiler: `atm_func` in `src/run.lua:85`
- atmos-lang compiler: `is_stmt` in `src/coder.lua:21`
  - prevents tail calls for: throw, spawn_in, emit, emit_in
  - notably absent: tasks (safe only because always in decl)
