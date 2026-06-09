# Plan: add `'clock'` await event

## Context

Subscribing to "every frame, with the delta" currently needs
an ad-hoc function pattern in each app:

```lua
local CLK = function (dt) return type(dt)=='number', dt end
every(CLK, function (us) ... end)
```

The bare-number clock convention is atmos-wide (both
`atmos/env/clock` and `env-sdl` emit a plain number = delta in
microseconds), so the tick pattern belongs in atmos core.

Goal: make it a first-class string event `'clock'`.

## Design

`'clock'` is a plain string event name recognized inside
`M.await`: it wakes on **any** bare-number emit and returns
that number (the delta in microseconds) to the task.

```lua
await('clock')                          -- next tick -> us delta
every('clock', function (us) ... end)   -- per-frame, us delta
```

Distinct from `await(<number>)` (duration countdown): `'clock'`
is "wake on the very next tick, give me its delta".

No global, no sentinel: it is just the string `'clock'`, so
`init.lua` is unchanged.

## Semantics

| point           | behavior                                       |
|-----------------|------------------------------------------------|
| match           | any **numeric** emit (the clock delta)         |
| value           | the raw number (microseconds delta)            |
| pre-yield       | yields and waits (no immediate fire)           |
| `emit('clock')` | does **not** match (only numbers do)           |

## Steps

### 1. Core branch  -- `atmos/run.lua`

In `M.await`, post-yield chain, after the `clk` (duration)
branch:

```lua
elseif tag == 'clock' then
    -- clock tick: wake on any bare-number emit, return the delta
    if type(emt) == 'number' then
        return emt
    end
```

A string `awt` already yields first (no top-of-loop branch
matches), so this single post-yield branch is the only change.

### 2. Version

Additive, backward-compatible -> bump atmos **patch**
(e.g. `0.7.x`).

## Tests  -- `tst/await.lua`

New `--- AWAIT / CLOCK ---` section, 3 `do` blocks:

| test        | asserts                                            |
|-------------|----------------------------------------------------|
| clock 1     | numeric emit returns its raw value (`510000` us)   |
| clock 2     | `'X'` / string `emit('clock')` ignored; `7` wakes  |
| every clock | `every('clock', f)` passes each delta; sums to 30  |

## Downstream (separate repos, after atmos ships)

Replace the local `CLK` helper with `'clock'`:

| repo / file              | change                                       |
|--------------------------|----------------------------------------------|
| `sdl-birds/birds-11.lua` | delete `local CLK`; `every(CLK,..)` -> `every('clock',..)` (3 sites) |
| `sdl-rocks`, `sdl-pingus`| same, if they use the clock delta            |
| `env-sdl` README Events  | mention `'clock'`                            |

## Docs (atmos repo)

| file                     | change                                       |
|--------------------------|----------------------------------------------|
| `api.md`                 | await row: `'clock'` wakes on number, returns delta |
| `guide.md`               | mention `'clock'` alongside duration await   |
| `env/clock/README.md`    | `'clock'` event                              |
| `env/README.md`          | `'clock'` event                              |

## Status

- [x] Tests added (`tst/await.lua`, end of file: clock 1, clock 2, every clock)
- [x] Core branch (`run.lua`: merged into `clk` branch as `clk or tag=='clock'`)
- [x] Full test suite passes (user-run)
- [x] Docs (api.md await row, guide.md snippet, env/clock + env READMEs)
- [ ] Downstream `CLK` -> `'clock'`

## Design note

- **Chosen:** string event `'clock'` handled by `M.await`. One
  branch, returns the exact delta.
- **Rejected:** global function-pattern (`_clock_`) and a
  sentinel value -- both are userland values; the string is a
  first-class await event with no new mechanism.
