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
- `M.loop` and `M.start` had a manual workaround:
  `return (function (...) return ... end)(body(...))`.
  Now replaced with `_no_tco_ <close> = nil`.
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
- `M.par_or` (line 871)
- `M.par_and` (line 881)
- `M.watching` (line 893)

## Analysis: runtime internal tail calls

The runtime has `return M.await(...)` in `M.toggle`,
`M.par_or`, `M.par_and`, and `M.watching`. These are NOT
proper tail calls because each function has `<close>` variables
in scope (coincidental protection, not explicit):

- `M.toggle` — `t <close>`, `_ <close>`
- `M.par` — `ts <close>`
- `M.par_or` — `ts <close>`
- `M.par_and` — `ts <close>`
- `M.watching` — `spw <close>`

In Lua 5.4, `return f()` with `<close>` variables is not a
proper tail call — close handlers must run after the return
value is computed. The stack frame is preserved.

Conclusion: no explicit fix needed for runtime internal calls
(coincidentally protected by existing `<close>` variables).

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

### M.loop / M.start — applied

Replaced the old `return (function (...) return ... end)(body(...))`
trick with `_no_tco_ <close> = nil` wrapping in the body
function. This prevents TCO when the user's loop/start body
is a tail call.

### M.task — pending discussion

The real protection point for all coroutine entries. Wrapping
in M.task would protect ALL user functions spawned everywhere
(par_or, par_and, watching, toggle, spawn, etc.):

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

If applied, M.loop/M.start wrapping becomes redundant (M.task
already wraps), but keeping it is harmless.

Status: **deferred** — user wants further discussion.

## Completed

- [x] Replace body trick in `M.loop` with `_no_tco_ <close>`
- [x] Replace body trick in `M.start` with `_no_tco_ <close>`
- [x] Add error trace tests for par_or, par_and, watching,
      toggle in `tst/errors.lua`
- [x] Analyzed and reverted `_no_tco_` from constructs
      (par_or, par_and, watching, toggle) — coincidental
      `<close>` protection is sufficient, and the real fix
      belongs in M.task

## Pending

### lua-atmos (runtime)
- [ ] Decide on `_no_tco_` wrapping in `M.task` (deferred)
- [ ] Add tests with tail calls to `debug.getinfo`-using
      functions (promote tail calls as idiomatic Lua):
      - `return tasks()` from a spawned function
      - `return throw(...)` from a spawned function
      - `return emit(...)` from a spawned function
- [ ] Run tests to verify

### lua-atmos (error traces) — issue #14
- [ ] Error stack trace should show construct names
      (par_or, par_and, watching, toggle), not just "task"
- [ ] Wrapping with `xcall` is the natural approach but
      changes `M.catch` semantics (runtime errors become
      meta_throw at construct level)

### atmos-lang (compiler)
- [ ] Remove `is_stmt` tail call guards from `src/coder.lua:21`
      - throw, spawn_in, emit, emit_in no longer need
        special treatment — the runtime now protects all
        coroutine entries
      - Requires M.task fix first
- [ ] Run atmos-lang tests to verify

## References

- atmos-lang "tasks 25: former bug - tail call"
- atmos-lang compiler: `atm_func` in `src/run.lua:85`
- atmos-lang compiler: `is_stmt` in `src/coder.lua:21`
  - prevents tail calls for: throw, spawn_in, emit, emit_in
  - notably absent: tasks (safe only because always in decl)
- GitHub issue #14: error trace construct names
