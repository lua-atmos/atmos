# Plan: tail-calls

## Goal

Prevent tail call optimization from eliminating stack frames
needed by `debug.getinfo(2)` in the Lua runtime (`lua-atmos`).

User code should be free to use tail calls — they are the
idiomatic style in Lua and the runtime must not crash.

## Context

- The atmos-lang compiler protects against this via `atm_func`
  wrapping and `is_stmt` codegen guards.
- The plain Lua runtime had NO protection: user functions passed
  to `M.spawn` become coroutine entry points. A tail call from
  there could eliminate the frame, causing `debug.getinfo(2)` to
  return nil and crash.

## Two-layer protection

### Layer 1: lua-atmos runtime (M.task) — safety

`_no_tco_ <close> = nil` wrapper in M.task prevents the
coroutine entry wrapper from being eliminated. This ensures
`debug.getinfo(2)` never returns nil (no crash).

Trade-off: when the user tail-calls throw/emit/tasks, the
error location shows `run.lua` (the wrapper) instead of the
user's file. The task chain still correctly shows user code.

### Layer 2: atmos-lang compiler (is_stmt) — precision

`is_stmt` in `src/coder.lua:21` prevents tail calls for
throw, spawn_in, emit, emit_in. This ensures error locations
always point to user code (not the runtime wrapper).

The two layers are complementary:
- Plain Lua users: safety (no crash), imprecise location
  on tail calls
- atmos-lang users: safety AND precise locations

## Fix details

### `_no_tco_ <close> = nil`

In Lua 5.4, `nil` is valid for `<close>` (no-op on close).
The compiler sees the to-be-closed annotation at compile time
and generates `OP_CLOSE` + `OP_RETURN` instead of
`OP_TAILCALL`, regardless of the runtime value.

Advantages over `return (f(...))`:
- preserves multiple return values
- explicit about intent (variable name documents why)
- searchable (`_no_tco_`)

### M.task — applied

Single protection point for all coroutine entries:

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

### M.loop / M.start — removed (redundant)

M.task now wraps all coroutine entries, so the old body
wrapping in M.loop and M.start was redundant and removed.

## Analysis: runtime internal tail calls

The runtime has `return M.await(...)` in `M.toggle`,
`M.par_or`, `M.par_and`, and `M.watching`. These are NOT
proper tail calls because each function has `<close>` variables
in scope (coincidental protection):

- `M.toggle` — `t <close>`, `_ <close>`
- `M.par` — `ts <close>`
- `M.par_or` — `ts <close>`
- `M.par_and` — `ts <close>`
- `M.watching` — `spw <close>`

No explicit fix needed for runtime internal calls.

## Completed

- [x] Replace body trick in `M.loop` with `_no_tco_ <close>`
- [x] Replace body trick in `M.start` with `_no_tco_ <close>`
- [x] Add error trace tests for par_or, par_and, watching,
      toggle in `tst/errors.lua`
- [x] Analyzed and reverted `_no_tco_` from constructs
      (par_or, par_and, watching, toggle) — coincidental
      `<close>` protection is sufficient
- [x] Apply `_no_tco_` wrapping in `M.task`
- [x] Remove redundant wrapping from `M.loop` and `M.start`
- [x] Add tail call tests showing imprecise but safe behavior
- [x] Decision: keep `is_stmt` in atmos-lang (precision layer)

## Pending

### lua-atmos (error traces) — issue #14
- [ ] Error stack trace should show construct names
      (par_or, par_and, watching, toggle), not just "task"
- [ ] Wrapping with `xcall` is the natural approach but
      changes `M.catch` semantics (runtime errors become
      meta_throw at construct level)

## References

- atmos-lang "tasks 25: former bug - tail call"
- atmos-lang compiler: `atm_func` in `src/run.lua:85`
- atmos-lang compiler: `is_stmt` in `src/coder.lua:21`
  - prevents tail calls for: throw, spawn_in, emit, emit_in
  - notably absent: tasks (safe only because always in decl)
- GitHub issue #14: error trace construct names
