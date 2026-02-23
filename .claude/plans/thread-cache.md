# lanes.gen caching for thread

## Status: done (implemented in atmos/run.lua)

## Problem

`lanes.gen("*", f)` compiles a lane prototype. Without
caching, each `thread(args, f)` call creates a new prototype
even when `f` is the same function. This is wasteful for
repeated calls with the same function.

## Solution

Cache `lanes.gen` results in a weak-key table keyed by
function identity:

```lua
local _gen_cache = setmetatable({}, { __mode = 'k' })

function M.thread (...)
    local args = { ... }
    local f = table.remove(args)
    ...

    local gen = _gen_cache[f]
    if not gen then
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
        _gen_cache[f] = gen
    end

    local linda = lanes.linda()
    local lane = assert(gen(linda, table.unpack(args)))
    ...
end
```

## Why caching is safe

`lanes.gen("*", wrapper)` records the function prototype.
The wrapper captures `f` as an upvalue. Serialization of `f`
(its bytecode + upvalues) happens at **lane launch time**
(`gen(linda, ...)`), NOT at gen creation time.

So a cached gen correctly picks up updated upvalue values:

```lua
local x = 10
local function compute (n) return n + x end

thread(5, compute)   -- cache miss, creates gen
                     -- lane launch serializes x=10
                     -- result: 15

x = 20
thread(5, compute)   -- cache HIT, reuses gen
                     -- lane launch serializes x=20
                     -- result: 25 (correct!)
```

### What determines cache key

- Function **identity** (same Lua object = cache hit)
- A new closure created each time = cache miss (correct,
  since it may capture different upvalue cells)

```lua
-- Cache HIT: same function object
local f = function (n) return n * 2 end
thread(3, f)    -- miss
thread(5, f)    -- hit

-- Cache MISS: new closure each iteration
for i = 1, 3 do
    thread(i, function (n) return n + i end)  -- miss x3
end
```

### Weak keys

`__mode = 'k'` means: if `f` is garbage collected (no more
references), the cached gen entry disappears automatically.
No memory leak from accumulated prototypes.

## Test case (thread 17 in `tst/thread.lua`)

```lua
do
    print("Testing...",
        "thread 17: cache hit with updated upvalue")
    spawn(function ()
        local x = 10
        local function compute (n) return n + x end

        local a = thread(5, compute)
        out(a)              -- 15 (5+10)

        x = 20
        local b = thread(5, compute)
        out(b)              -- 25 (5+20, cache hit, new x)
    end)
    os.execute("sleep 0.1")
    emit()
    os.execute("sleep 0.1")
    emit()
    assertx(out(), "15\n25\n")
    atmos.stop()
end
```
