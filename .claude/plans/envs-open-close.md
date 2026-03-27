# Envs open/close analysis

## M.loop lifecycle (run.lua:327-355)

- Lines 331-333: call `env.open()` for each registered env before
  the main loop.
- `M.stop()` (line 335 via defer, lines 364-372): call
  `env.close()` for each env on exit.

## Env status

| Env        | open             | close            | Needs? | Why                                    |
|------------|------------------|------------------|--------|----------------------------------------|
| env-sdl    | SDL/IMG/TTF/MIX init + audio | SDL/IMG/TTF/MIX quit | Yes    | C libs need init/quit for OS resources |
| env-iup    | iup.Open         | iup.Close        | Yes    | C GUI toolkit requires Open/Close      |
| env-socket | none             | none             | No     | sockets are per-connection, no global  |
| env-pico   | empty (commented)| pico.init(false) | Partial| init at require-time, asymmetric       |

## Issues

- [ ] env-pico: `pico.init(true)` runs at require-time (line
  13-14), not inside `open`.
  `close` calls `pico.init(false)`.
  TODO on line 12 acknowledges the asymmetry.
  Fix: move `pico.init(true)` + `pico.set.expert(...)` into
  `open`.

## Notes

- env-sdl and env-iup genuinely need both open and close
  because they wrap C libraries with explicit lifecycle.
- env-socket needs neither; socket creation is per-use.
- env-pico needs close but open is currently a no-op due to
  init being at require-time.
