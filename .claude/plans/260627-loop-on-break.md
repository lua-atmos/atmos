# remove loop_on / _break_ / atm-loop

## Goal

Drop the loop/break sugar from the lua-atmos runtime library.
Keep the runtime to primitives only:
`loop` (driver), `await`, `emit`, `spawn`, `catch`, `throw`.
Looping over events becomes explicit `while true do await(...) end`.

Supersedes the earlier break-value fix: `M.loop_on` and its
`loop_on 5` test are deleted, so that fix is moot.

## Why

- `loop_on` / `_break_` are language constructs (`loop on` / `break`).
- The language `atmos-lang` already owns them via its own runtime
  (`src/run.lua` `atm_loop` / `atm_break`), independent of this library.
- The library should expose primitives, not language sugar.

## Symbols removed

| symbol    | role                              | refs                |
| --------- | --------------------------------- | ------------------- |
| `loop_on` | event loop compound               | ~150+ sites         |
| `_break_` | break out of `loop_on`            | 3 sites (tst only)  |
| `atm-loop`| throw tag wiring the two          | internal, run.lua   |

## Replacement recipe

`loop_on(pat, body)` is equivalent to:

```lua
while true do
    <body-params> = await(pat)
    <body-stmts>
end
```

- no params:    `while true do await(pat); <body> end`
- one param e:  `while true do local e = await(pat); <body> end`
- `_break_()`:  plain Lua `break` (no value carried).
- time/table/string patterns map 1:1, since public `await`
  already supplies `TIME` (`init.lua:81`).

## Files in THIS worktree (atmos)

| file                              | place                  | action                       |
| --------------------------------- | ---------------------- | ---------------------------- |
| `atmos/run.lua`                   | `M._break_` (~208-212) | delete                       |
| `atmos/run.lua`                   | `M.loop_on` (~841-858) | delete (with `atm-loop`)     |
| `atmos/init.lua`                  | line 21                | drop `_break_` export        |
| `atmos/init.lua`                  | line 96                | drop `loop_on` export        |
| `atmos/env/clock/exs/hello.lua`   | line 6                 | rewrite to `while`+`await`   |
| `atmos/api.md`                    | §5 (333, 344-363)      | remove `loop_on` entry/link  |
| `atmos/README.md`                 | 43, 86, 99, 112-115    | rewrite example + prose      |
| `atmos/guide.md`                  | 272-278, 405           | rewrite `loop_on` statement  |
| `atmos/HISTORY.md`                | 5, 40, 54              | note removal under v0.8      |

Test call-site migrations (existing tests, not new tests):

| file              | sites                                            |
| ----------------- | ------------------------------------------------ |
| `tst/await.lua`   | 349-355 (`_break_`), 447-450 (reject fn 3)       |
| `tst/guide.lua`   | 142, 229                                          |
| `tst/readme.lua`  | 9                                                |
| `tst/task.lua`    | 174, 387-444 (loop_on 1-4), 447-452 (loop_on 5)  |
| `tst/tasks.lua`   | 143                                              |
| `tst/toggle.lua`  | 145, 204-206, 225-227, 248, 269-271             |

Note: `loop_on 1-5` tests lose their subject; convert to plain
`while`+`await` behavior tests or drop the break-value ones.

## Files OUTSIDE this worktree (cross-repo, do NOT edit here)

Each is its own repo; migrate in its own session/worktree.

| project      | files                                       |
| ------------ | ------------------------------------------- |
| env-iup      | exs/button-counter, hello, iup-net          |
| env-pico     | exs/across, click-drag-cancel, hello        |
| env-sdl      | exs/click-drag-cancel, hello                |
| env-socket   | exs/hello                                   |
| pico-birds   | birds-01..11                                |
| sdl-birds    | birds-01..11                                |
| pico-rocks   | battle, main, ts                            |
| sdl-rocks    | battle, main, ts                            |
| sdl-pingus   | level, menu, pingu                          |

## Reconcile with atmos-lang

| layer                 | loop/break                        | impact   |
| --------------------- | --------------------------------- | -------- |
| atmos-lang (compiler) | `atm_loop` / `atm_break` (own rt) | none     |
| lua-atmos (this lib)  | `loop_on` / `_break_`             | removed  |

The language keeps `loop on` / `break` keywords unchanged.
Only the library sugar is dropped; the two never shared code.

## Consideration (not steps)

- Breaking API change -> warrants a version/rockspec bump,
  like the `every`->`loop_on` rename. Handle at release time.

## Pending

- [ ] Delete `M._break_`, `M.loop_on`, `atm-loop` from `run.lua`.
- [ ] Drop `_break_` / `loop_on` exports from `init.lua`.
- [ ] Migrate `atmos/env/clock/exs/hello.lua`.
- [ ] Migrate test call sites (await, guide, readme, task, tasks,
      toggle).
- [ ] Update docs (api.md, README.md, guide.md, HISTORY.md).
- [ ] Cross-repo: migrate 9 sibling projects (separate sessions).
