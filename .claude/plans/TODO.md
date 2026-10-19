# TODO

- envs: adapt to timers and `atmos.gc` (lua-atmos/atmos#26)
    - `socket`: `select` timeout from `atmos.next()`, tick before input
    - `iup`: one-shot timer at `atmos.next()`, real elapsed time
    - `pico`, `sdl`: optional `min(frame, next())`
    - `js`: check `emit('clock', ...)`, call `atmos.gc()` per callback
- `stop` called inside a task: sweeps root mid-traversal

<!-- ------------------------------ WON'T DO ------------------------------ -->

- `tasks()` in loop: pools stay in parent `dns` (gc)
    - by design: closed pool still usable
- `loop`: no sweep before first `step` (gc)
    - tasks dead in initial body run survive 1 step
- `await(0)` loop never yields (timers)
- cap on pieces per tick (timers)
- whole-tick `'clock'` (timers)
- `clock` env: sleep instead of busy loop (timers)
    - `os.clock` is CPU time: needs wall clock
