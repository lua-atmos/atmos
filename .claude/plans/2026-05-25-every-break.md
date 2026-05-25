# Plan: `break()` inside `every` (and `par`/`watching`)

## Repo

Fix lives in **lua-atmos** (the runtime), not in this `atmos` compiler repo.

- source: `atmos/run.lua` (lua-atmos repo)
- installed: `/usr/local/share/lua/5.4/atmos/run.lua`

## Problem

```atmos
spawn {
    every true {
        break()
    }
    print :ok
}
emit :ok
```

Surfaces as an uncaught `==> atm-loop` and never prints `ok`.

## Root cause

```
break()  ->  atm_break()  ->  throw('atm-loop', ...)
```

| construct | compiles to                          | catches `atm-loop`? |
|-----------|--------------------------------------|---------------------|
| `loop`    | `atm_loop(fn)` -> `catch('atm-loop')`| yes                 |
| `every`   | runtime `M.every(awt, cb)`           | **no**              |

`M.every` runs `while true do blk(...) end` with no catch, so the
`atm-loop` throw escapes the loop and the task.

## Fix

Wrap the `while` loop of `M.every` in `M.catch('atm-loop', ...)`,
mirroring how `atm_loop` works.

`M.every` (currently ~line 873):

```lua
function M.every (...)
    assertn(2, M.me(true), "invalid every : expected enclosing task")
    local t = { ... }
    local blk = table.remove(t, #t)
    M.catch('atm-loop', function ()
        while true do
            blk(M.await(table.unpack(t)))
        end
    end)
end
```

`M.catch` already discards the matched throw and returns control, so the
enclosing block continues normally after `break()`.

## Verify same gap

Check whether `break()` inside a `par` / `par_or` / `par_and` /
`watching` branch needs the same treatment (those branches are spawned
tasks; confirm break is meant to break a loop inside the branch, not the
branch itself).

## Verification

Run the repro above with `./atmos /tmp/x.atm`; it should print `ok`
instead of raising `atm-loop`.

## Design

Rule: a control-flow primitive moves to lua-atmos only if a lua-atmos
concurrency primitive must *catch* it.

| keyword | tag      | catcher                         | home      |
|---------|----------|---------------------------------|-----------|
| break   | atm-loop | atm_loop (lang) + every (core)  | lua-atmos |
| return  | atm-func | atm_func (lang) only            | atmos-lang|
| escape  | atm-do   | atm_do (lang) only              | atmos-lang|

So only `break` migrates to lua-atmos as `_break_`.
`M.every`'s catch must be tag-specific so `return`/abort pass through.

## Status

- [x] reproduced bug via `./atmos /tmp/x.atm` -> `==> atm-loop`
- [x] lua-atmos side done:
    - `M.brk` -> `throw('atm-loop', ...)` (tail call) in `run.lua`
    - `_break_ = run.brk` export in `init.lua`
    - `M.every` wraps `while` in `catch('atm-loop', ...)`
    - test `every 3: break` now uses `_break_()`
    - test `every 4: return passes through` (guards tag-specific catch)
- [ ] RUN lua-atmos tests (user) to confirm green
- [ ] investigate `par`/`watching`
- [ ] atmos-lang side: coder emits `_break_`, drop `atm_break`,
      `atm_until`/`atm_while` call `_break_`, add `.atm` tests
