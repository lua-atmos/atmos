v0.7 (jun/26)
-------------

- Additions:
    - `abort` task and tasks
    - `await` patterns:
        - any/all tasks in a pool
            - `await(ts, ['any'|'all'])`
        - logical combinators:
            - `{ tag='or',  ... }`, `{ tag='and', ... }`, `{ tag='not', x }`
        - predicates:
            - `{ tag='until', pat, ... }`, `{ tag='while', pat, ... }`
    - `toggle(..., [filter], ...)`: optional filter pattern to keep reacting
    - `__atmos` metamethod: custom await matching for user types
- Removals:
    - multi-arg events:
        - `emit` now only receives one argument
            - `emit('X', 10)` -> `emit { tag='X', v=10 }`
        - `await` now only receives and returns one argument
            - exception: `await(ts, ...)` above
    - `_and_` / `_or_`: see "logical combinators" above
- Modifications:
    - `clock { ... }` -> simply `dt` in microseconds
        - `await(5 * _s_)` awaits 5 seconds
        - `await('clock')` awaits any `dt` and returns it
        - constants `_us_`, `_ms_`, `_s_`, `_min_`, `_h_`, `_day_`
        - `S.from(clock)` -> `S.fr_await(<us>)`
- Environments:
    - `open`+`close` changed to main body + `quit`
- Bug fixes:
    - `break()` inside `every`

v0.6 (mar/26)
-------------

- Additions:
    - `thread` block (CPU parallelism via LuaLanes)
- Modifications:
    - `loop` (was `call`)
- Environments:
    - new API: `open`, `step`, `close`
    - multi-env mode system (primary/secondary)
    - new environment `env-js`
    - all extracted to separate repos:
        - `env-iup`, `env-js`, `env-pico`, `env-sdl`, `env-socket`

v0.5 (jan/26)
-------------

- Changes:
    - Environments
        - `lua-sdl2` `v2.0`
        - `pico-sdl` `v0.2`
- Bug fixes:
    - tasks count ignores dead tasks
    - pico env: function predicates, mouse buttons

v0.4 (nov/25)
-------------

- Added module `atmos.x` (`copy`, `tostring`, `print`).
- Modifed clock emit from `emit(clock{ms=10})` to `emit('clock',10)`.
- Environments:
    - Added `pico` environment.
    - Added `env.now` to all environments.
    - `sdl`:
        - Removed `sdl.` prefix from all events.
        - Added `env.window(...)` init api.

v0.3 (oct/25)
-------------

- Added the `f-streams` library.
- Bug fix: task abortion.

v0.2 (aug/25)
---------------

- (no history)

v0.1 (jul/25)
---------------

- (no history)
