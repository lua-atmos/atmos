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
