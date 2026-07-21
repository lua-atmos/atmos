# Plan: `await` spawn table drops arguments after a `nil`

Runtime half of the fix.
The compiler half lives in
`/x/atmos-lang/atmos/.claude/plans/260721-spawn-bug.md`.

## Problem

An awaited spawn whose argument list contains a `nil` loses every
argument after it.

```
task T (a, b, c) { print(a) print(b) print(c) }

spawn T(nil, 10, 20)    ;; OK  -> nil / 10 / 20
await T(nil, 10, 20)    ;; BUG -> nil / nil / nil
```

`spawn` compiles to a direct call and is unaffected.
`await` round-trips the call through a combinator table.

## Cause

`atmos/run.lua:562`, branch `tag == 'spawn'`:

```lua
return M.await(time, M.spawn(debug.getinfo(2), nil, false, awt[1],
    table.unpack(awt, 2, #awt)))
```

The incoming table is

```lua
{ ['tag'] = 'spawn', [1] = T, [2] = nil, [3] = 10, [4] = 20 }
```

`#awt` on a table with a `nil` hole at `[2]` may return any valid
border; here it is `1`, so `table.unpack(awt, 2, 1)` yields nothing
and `T` receives no arguments.

## Solution

Take the count from an explicit `n` field, emitted by the compiler,
instead of inferring it with the length operator.

```lua
return M.await(time, M.spawn(debug.getinfo(2), nil, false, awt[1],
    table.unpack(awt, 2, awt.n or #awt)))
```

`n` counts the items after the tag, i.e. prototype plus arguments,
matching the `[1..n]` numeric keys.
The `or #awt` fallback keeps hand-written combinator tables (which
never carry `n`) working unchanged.

Only the `spawn` shape needs this: `or` / `and` / `not` / `until` /
`while` are built from non-nil sub-patterns and are consumed by
`ipairs` or a fixed arity.

## Alternative (runtime only)

If the compiler cannot be changed, scan for the largest integer key
instead of using `#`.
Exact for interior nils; trailing nils are absent from the table but
arrive as `nil` parameters anyway, so behaviour is still correct.
Rejected as the primary fix: O(n) per await and still guesswork.

## Files

| file             | place              | change                        |
| ---------------- | ------------------ | ----------------------------- |
| `atmos/run.lua`  | `M.await`, l. 562  | `table.unpack(awt,2,awt.n or #awt)` |

## Status -- COMPLETE

- [x] failing test added (`tst/await.lua`, "await proto 2b")
      the carrier must use explicit numeric keys (`[1]=T, [2]=nil, ...`),
      as the compiler emits: a positional constructor `{T, nil, 10, 20}`
      sizes the array part to 4, so `#` returns 4 and hides the bug
- [x] runtime uses `n`
- [x] paired compiler change landed in atmos-lang (`mk_tagged`)
- [x] atmos-lang suite green (user-verified)

Note: the compiler emits `n` for every tagged table, not only
`spawn`; the `or #awt` fallback still covers hand-written tables.
