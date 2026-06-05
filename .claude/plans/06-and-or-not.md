# and / or / not / clock / toggle — value events (lua-atmos runtime)

## Outcome (what shipped)

The runtime moved to a **value-event** model and inlined matching.
The original "passive `check_ret`" plan was abandoned; this records the
design that landed.

Runtime-only (atmos/run.lua + init.lua + streams.lua + env/clock).
Language keyword sugar is a separate atmos-repo concern (see §Language).

## Event model

- An event is a **value**: a string `'X'`, a number, or a tagged table
  `{tag=K, v1, v2, ...}`.
- `emit(emt)` takes a **single** event (no-arg `emit()` = a nil wake signal).
  `emit('X', v)` is invalid -> use `emit{tag='X', v}`.
- `clock{...}` returns `{tag='clock', ms=N}`; ticks are `{tag='clock', ms, now}`.

## await (single arg)

`await(awt)` takes one pattern (tasks pools may pass a mode:
`await(ts, 'any'/'all')`).
Matching is **inlined** in `M.await`'s loop (no `check_ret`/`await_to_table`):

| pattern                  | match                                            |
| ------------------------ | ------------------------------------------------ |
| `true` / `false`         | any event / never                                |
| string / number          | `M.is(emt, awt)`                                 |
| `{tag=K, v1, ...}`        | `M.is` over every field (tag + values)           |
| `clock{...}`             | countdown on `{tag='clock'}` ticks               |
| task / tasks             | completion (`ret,task` / `ret,task,ts`)          |
| function                 | `awt(emt)` predicate (nil-safe: `v and ...`)     |
| `{tag='or'/'and', ...}`   | `par_or` / `par_and` over sub-awaits             |
| `{tag='not', x}`          | `par_or(await x -> false, await(true) -> true)`  |

Return shape: await returns the **event** (read `.tag` / `[1]`); task ->
`(ret, task)`; tasks -> `(ret, task, ts)`; clock -> `('clock', ms, now)`.

Event-side `__atmos` (event's metatable) is consulted post-yield,
**self-first** (`mte.__atmos(emt, awt)`); pattern-side is `mta.__atmos(awt, emt)`.
The `nil` opt-out (fall-through to default) was **removed**: a handler returns
`true`(+vals) to match or `false`/`nil` to not.

## toggle

- task form: `toggle(t, on)` (`on` boolean; filter only with `on==false`).
- string form: `toggle(e, [filter,] body)` — **body is the last arg**, filter
  optional preceding (matches `every`/`watching` block-last). Pure sugar:
  `spawn body; loop { await{tag=e,false}; toggle(body,false,filter);
  await{tag=e,true}; toggle(body,true) }`.
- filter = exactly one pattern (`assert select('#',...)<=... ` style).

Filter via an **off-tree hidden gate task**: `t._.toggle = {task=gate, pass=}`.

- `emit(t)`, when toggled, drives the gate **subtree** explicitly first
  (`emit(time, t._.toggle.task, emt)`), then gates unless
  `t._.toggle.pass == time`. The gate awaits the filter and stamps
  `pass = TIME` on a match.
- gate created with `M.task` (NOT `M.spawn`) so it is **off-tree** (not in any
  `dns`) — `emit(t)` is its sole driver, ordering by construction; combinators
  work for free (the gate's `par_or` children are in its own subtree).
- toggle-on / body-close just `meta_task.__close` the gate; no `dns` surgery.

## Files

| file                         | change                                          |
| ---------------------------- | ----------------------------------------------- |
| atmos/run.lua                | clock, inlined `M.await` matcher, `M.emit`/`emit` single-event, `M.toggle` hidden gate, `meta_task.__close` gate cleanup |
| atmos/init.lua               | `emit` (allows no-arg), `await = run.await`, `toggle` wrappers |
| atmos/streams.lua            | tagged `emit_in{tag=n,v}`, `await(n)->e[1]`, `paror` |
| atmos/env/clock/init.lua     | `emit{tag='clock', ms, now}`                    |
| tst/*.lua                    | `{tag=}` events, single-arg emit/await, event-shape reads, `every`/`watching` block-last, toggle body-last |

## Verification

`cd tst && lua5.4 all.lua` — green (user-run).

## Pending

- [ ] uncomment filter 4 assert (tst/toggle.lua) -> `"1\n2\n109\n"`
- [ ] drop the `-- TODO: remove` arity asserts (emit / M.emit / M.toggle)
- [ ] decide on the commented `__atmos` nil-opt-out tests (tst/envs.lua)
- [ ] env-iup / env-pico / env-sdl: 3-arg clock emit, `__atmos` nil->false +
      self-first args, old `{'==',...}` patterns, exs/ (separate repos)
- [ ] Language (atmos repo): `and`/`or`/`not` + event sugar -> `{tag=...}`,
      clock stdlib, document passive-match vs `par_*`

## Done

- [x] clock as `{tag='clock', ms}` value event
- [x] single-arg `await` (+ tasks mode) with inlined matcher
- [x] single-event `emit` (no-arg wake allowed)
- [x] tagged-table value patterns (`M.is` per field)
- [x] `or`/`and`/`not` via `par_*` (structured)
- [x] event/pattern `__atmos` (self-first; opt-out removed)
- [x] toggle filter via off-tree hidden gate; block form = sugar
- [x] streams adapter + env/clock converted
- [x] all tst/ converted; `all.lua` green
