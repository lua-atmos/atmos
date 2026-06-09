# Plan: add `_clock_` await primitive

## Context

Subscribing to "every frame, with the delta" currently needs
an ad-hoc function pattern in each app:

```lua
local CLK = function (dt) return type(dt)=='number', dt end
every(CLK, function (us) ... end)
```

The bare-number clock convention is atmos-wide (both
`atmos/env/clock` and `env-sdl` emit a plain number = delta in
microseconds), so the tick pattern belongs in atmos core,
alongside the `_us_ _ms_ _s_` duration constants.

Goal: make it a first-class global `_clock_`.

## Steps

### 1. Define `_clock_`

File: `atmos/init.lua`, after the constants block (`_day_`).

```lua
-- clock tick pattern: matches a bare-number clock emit;
-- await/every returns the elapsed delta (microseconds)
_clock_ = function (dt) return type(dt)=='number', dt end
```

Composes with `await`/`every`/`watching`/`par` because the
core already supports function patterns (`run.lua:584`).
No `run.lua` change needed.

Usage:

```lua
every(_clock_, function (us) ... end)   -- per-frame, us delta
await(_clock_)                          -- next tick
```

### 2. Semantics (document in manual)

| point     | behavior                                          |
|-----------|---------------------------------------------------|
| match     | any **numeric** emit (the clock delta)            |
| value     | the raw delta in **microseconds**                 |
| pre-yield | `_clock_(nil)` -> false, so it yields and waits   |
| caveat    | also matches manual `emit(N)` (numeric) -- inherent to the bare-number clock convention |

### 3. Version

Additive, backward-compatible -> bump atmos **patch**
(e.g. `0.7.x`).

## Downstream (separate repos, after atmos ships)

Replace the local `CLK` helper with the global `_clock_`:

| repo / file              | change                                   |
|--------------------------|------------------------------------------|
| `sdl-birds/birds-11.lua` | delete `local CLK`; `every(CLK,..)` -> `every(_clock_,..)` (3 sites) |
| `sdl-rocks`, `sdl-pingus`| same, if they use the clock delta        |
| `env-sdl` README Events  | mention `_clock_`                         |

## Design note

- **Chosen:** global function-pattern. Zero core risk, one
  line, returns the exact delta.
- **Rejected:** special-case `await{tag='clock'}` in
  `run.lua`. More invasive, no benefit over the global.
