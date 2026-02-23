# Non-blocking xspawn with custom xtask handle

## Context

Current `xspawn` blocks in a polling loop (`await(true)` +
`linda:receive`), returning the lane result directly. This
doesn't match the `task`/`spawn` pattern where `spawn` returns
immediately and `await(handle)` waits later. Also, `lanes` is
eagerly required at module top, penalizing programs that never
use xtask.

## Goal

Make xtask/xspawn behave like task/spawn:
1. `xspawn` returns a handle immediately (non-blocking)
2. `await(handle)` waits for lane completion
3. `handle <close>` cancels the lane via `__close`
4. `require("lanes")` is lazy (inside `xtask`)
5. `xspawn` works anywhere (no enclosing task required)
6. TODO: xemit, xawait, xchannel(linda) for future

## Design

Two metatables:
- `meta_xtask_proto` — for prototypes (from `xtask(f)`)
- `meta_xtask` — for handles (from `xspawn(xt, ...)`)
  with `__close` that cancels the lane

Registry `_xtasks_` (weak-key table) tracks active handles.
`poll_xtasks()` in `M.loop` checks lindas and emits completed
handles to wake awaiting tasks.

## Changes — `atmos/run.lua`

### 1. Lazy lanes (line 3)
```lua
-- WAS: local lanes = require("lanes").configure()
local lanes
```

### 2. Registry + metatables (near line 822)
```lua
local _xtasks_ = setmetatable({}, { __mode = 'k' })

local meta_xtask_proto = {}

local meta_xtask = {
    __close = function (h)
        if h._.lane then
            pcall(function ()
                h._.lane:cancel(0, true)
            end)
        end
        _xtasks_[h] = nil
    end,
}
```

### 3. M.xtask (lines 824-836) — lazy require, new metatable
```lua
function M.xtask (f)
    assertn(2, type(f)=='function',
        "invalid xtask : expected function")
    if not lanes then
        lanes = require("lanes").configure()
    end
    return setmetatable({
        gen = lanes.gen("*", function (linda, ...)
            local r = table.pack(pcall(f, ...))
            if r[1] then
                linda:send("ok",
                    { true, table.unpack(r, 2, r.n) })
            else
                linda:send("ok",
                    { false, tostring(r[2]) })
            end
        end)
    }, meta_xtask_proto)
end
```

### 4. M.xspawn (lines 838-864) — non-blocking, returns handle
```lua
function M.xspawn (xt, ...)
    if type(xt) == 'function' then
        xt = M.xtask(xt)
    end
    assertn(2, getmetatable(xt)==meta_xtask_proto,
        "invalid xspawn : expected xtask prototype")

    local linda = lanes.linda()
    local lane = assert(xt.gen(linda, ...))

    local h = setmetatable({
        ret = nil,
        _ = {
            linda = linda,
            lane  = lane,
            done  = false,
            err   = nil,
        },
    }, meta_xtask)

    _xtasks_[h] = true
    return h
end

-- TODO: xemit, xawait, xchannel(linda)
-- for inter-xtask communication
```

### 5. poll_xtasks (new, near xtask section)
```lua
local function poll_xtasks ()
    for h in pairs(_xtasks_) do
        local key, r = h._.linda:receive(0, "ok")
        if key then
            _xtasks_[h] = nil
            h._.done = true
            if r[1] then
                h.ret = r[2]
            else
                h._.err = r[2]
            end
            M.emit(false, 'global', h)
        end
    end
end
```

### 6. M.loop (line ~334) — add poll_xtasks call
```lua
while true do
    if coroutine.status(t._.th) == 'dead' then
        break
    end
    poll_xtasks()                          -- NEW
    local quit = false
    for _, env in ipairs(_envs_) do
        ...
```

### 7. await_to_table (line 614) — recognize meta_xtask
```lua
if (getmetatable(e) == meta_task)
    or (getmetatable(e) == meta_tasks)
    or (getmetatable(e) == meta_xtask) then
```

### 8. check_task_ret (lines 462-467) — xtask fast path
```lua
if ... meta_task ... then
    return true, t[1].ret, t[1]
elseif (getmetatable(t[1]) == meta_xtask)
    and t[1]._.done then
    if t[1]._.err then
        error(t[1]._.err, 0)
    end
    return true, t[1].ret
else
    return false
end
```

### 9. check_ret (line ~544) — xtask on emit
```lua
if getmetatable(e) == meta_task then
    return true, e.ret
elseif getmetatable(e) == meta_xtask then
    if e._.err then
        error(e._.err, 0)
    end
    return true, e.ret
elseif getmetatable(e) == meta_tasks then
```

### 10. _or_ and _and_ (lines 679, 696) — add meta_xtask
```lua
if getmetatable(x)==meta_task
    or getmetatable(x)==meta_tasks
    or getmetatable(x)==meta_xtask
    or x.tag then
```

### 11. M.is (line ~100) — add xtask type
```lua
elseif mt==meta_xtask and x=='xtask' then
    return true
```

### 12. M.stop (lines 360-368) — cancel active xtasks
```lua
function M.stop ()
    for h in pairs(_xtasks_) do
        meta_xtask.__close(h)
    end
    meta_tasks.__close(TASKS)
    ...
```

## Changes — `tst/xtask.lua`

All tests need `await()` around xspawn results.

Pattern: `local v = xspawn(fn)` →
`local h <close> = xspawn(fn); local v = await(h)`

- **xspawn 1**: rewrite — test xspawn outside task
  (no longer an error)
- **xspawn 2**: simplify — remove spawn wrapper
  (xspawn no longer requires enclosing task)
- **xspawn 3**: convert to loop + await (remove sleep/emit)
- **xspawn 4-10**: add await(h) pattern
- **xspawn 11**: error propagation via await(h)
- **xspawn 12-15**: add await(h) pattern
- **xtask 2-3**: add await(h) pattern
- **NEW xspawn 16**: `h <close>` cancels lane
- **NEW xspawn 17**: `await(_or_(h, 'X'))` works

## Changes — `atmos/init.lua`

No changes. `xtask = run.xtask` / `xspawn = run.xspawn`
still work.

## Note

`poll_xtasks` is only in `M.loop`. `M.start` (env-driven)
doesn't have its own scheduler loop, so xtask polling there
would require a separate mechanism (future work if needed).

## Verification

- Run `cd tst && lua5.4 all.lua` (or just `dofile "xtask.lua"`)
- All 19 existing tests pass with new await pattern
- New tests (close, _or_) pass
