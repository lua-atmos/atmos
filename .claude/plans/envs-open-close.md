# Envs: drop open, rename close to quit

## Decision

`require` IS the open — module body does init.
Only `quit` (formerly `close`) is needed for teardown.

```
require       step...step      quit
  |               |              |
  module+init     event loop     release C resources
```

## Framework changes (run.lua)

- [x] `loop` (lines 331-332): remove `env.open()` loop
- [x] `start` (line 360): remove `env.open()` call
- [x] `stop` (lines 367-368): rename `env.close` to `env.quit`

## Env changes

| Env        | Action                                          |
|------------|-------------------------------------------------|
| env-sdl    | move `open` body to module top-level, rename `close` to `quit` |
| env-iup    | remove `open = iup.Open` (likely redundant), rename `close` to `quit` |
| env-socket | no change (has neither)                         |
| env-pico   | remove empty `open`, rename `close` to `quit`   |

## Testing

- [x] Auto test: `tst/envs.lua` + added to `tst/all.lua`
- [ ] Manual test: env-iup example with sockets

## Notes

- env-pico was the only broken env (init at require-time,
  empty open). New design makes it the reference pattern.
- env-iup: `require("iuplua")` likely calls `iup.Open`
  internally; the explicit `open = iup.Open` was probably
  redundant. Confirm when editing.
