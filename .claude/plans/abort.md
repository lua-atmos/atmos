# Abort Tasks (Issue #18)

- https://github.com/atmos-lang/atmos/issues/18

## Goal

Implement `abort(t)` / `abort(ts)` to explicitly abort a task
or tasks container.

## Analysis

The `__close` metamethods on `meta_task` and `meta_tasks` already
handle the core abort logic (closing coroutines and children).
The `abort` function needs to:

1. Call `__close` on the target (task or tasks container)
2. Mark the parent for GC so dead task gets removed from `_.dns`
3. Handle self-abort (like `emit` does at run.lua:784-787)

## Changes

| File             | Place                          | Description                                                       |
|------------------|--------------------------------|-------------------------------------------------------------------|
| `atmos/run.lua`  | `M.abort` (after `M.toggle`)   | New function: validate, `__close`, mark parent GC, self-abort     |
| `atmos/init.lua` | global `abort` (near line 61)  | Expose `abort = run.abort`                                        |

## Implementation

### `atmos/run.lua` — new `M.abort` (~after line 822)

```lua
function M.abort (t)
    assertn(2, getmetatable(t)==meta_task or getmetatable(t)==meta_tasks, "invalid abort : expected task")
    getmetatable(t).__close(t)
    if t._.up then
        t._.up._.gc = true
    end
    local me = M.me(true)
    if me and me._.status=='aborted' then
        -- TODO: lua5.5
        coroutine.yield()
    end
end
```

### `atmos/init.lua` — add after line 61

```lua
abort    = run.abort
```

## Progress

- [x] Add `M.abort` to `atmos/run.lua`
- [x] Expose `abort` in `atmos/init.lua`
- [x] Create `tst/abort.lua`
- [x] Test
- [x] Update docs
- [ ] Add to atmos-lang
