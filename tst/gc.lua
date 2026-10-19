local atmos = require "atmos"
require "test"

print '--- GC ---'

-- iterations per case
local N = 10

--[[
-- Counts direct children of the current task.
-- Inputs:
--  - (none)
-- Outputs:
--  - [number]: size of `dns` of the enclosing task
-- Callers:
--  - gc tests [gc.lua]: check dead tasks were collected
--]]
local function dns ()
    return #xtask()._.dns
end

--[[
-- Emits 'X' a number of times, sweeping around each (as an env step).
-- Inputs:
--  - n [number]: number of emits
-- Outputs:
--  - (none)
-- Callers:
--  - gc tests [gc.lua]: drive loops and trigger gc
--]]
local function emits (n)
    for i=1, n do
        atmos.gc()  -- also sweeps the initial `spawn`
        emit('X')
        atmos.gc()
    end
end

-- NORMAL TERMINATION

do
    print("Testing...", "gc 1: spawn, normal end")
    spawn(task(function ()
        local n
        for i=1, N do
            spawn(task(function () await('X') end))
            if i == N then
                n = dns()   -- live child + previous dead (same reaction)
            end
            await('X')
        end
        await('X')
        out(n, dns())
    end))
    emits(N+1)
    assertx(out(), "2\t0\n")
    atmos.stop()
end

do
    print("Testing...", "gc 2: await T(), normal end")
    spawn(task(function ()
        for i=1, N do
            await(task(function () await('X') end))
        end
        await('X')
        out(dns())
    end))
    emits(N+1)
    assertx(out(), "0\n")
    atmos.stop()
end

do
    print("Testing...", "gc 3: par_all")
    spawn(task(function ()
        for i=1, N do
            par_all(
                function () await('X') end,
                function () await('X') end
            )
        end
        await('X')
        out(dns())
    end))
    emits(N+1)
    assertx(out(), "0\n")
    atmos.stop()
end

do
    print("Testing...", "gc 4: await and")
    spawn(task(function ()
        for i=1, N do
            await {tag='and', 'X', 'X'}
        end
        await('X')
        out(dns())
    end))
    emits(N+1)
    assertx(out(), "0\n")
    atmos.stop()
end

do
    print("Testing...", "gc 5: top-level spawn")
    local up
    for i=1, N do
        local t = spawn(task(function () await('X') end))
        up = t._.up
    end
    emits(1)
    assertx(#up._.dns, 0)
    atmos.stop()
end

-- ABORT

do
    print("Testing...", "gc 6: abort(t)")
    spawn(task(function ()
        for i=1, N do
            local t = spawn(task(function () await(false) end))
            abort(t)
        end
        local n = dns()     -- dead, not swept yet
        await('X')
        out(n, dns())
    end))
    emits(1)
    assertx(out(), N.."\t0\n")
    atmos.stop()
end

do
    print("Testing...", "gc 7: do_spawn <close>")
    spawn(task(function ()
        for i=1, N do
            local _ <close> = do_spawn(function () await(false) end)
            await('X')
        end
        await('X')
        out(dns())
    end))
    emits(N+1)
    assertx(out(), "0\n")
    atmos.stop()
end

-- PAR_ANY FAMILY (losers closed by throw)

do
    print("Testing...", "gc 8: par_any")
    spawn(task(function ()
        for i=1, N do
            par_any(
                function () await('X') end,
                function () await('Y') end
            )
        end
        local n = dns()     -- last winner+loser, not swept yet
        await('X')
        out(n, dns())
    end))
    emits(N+1)
    assertx(out(), "2\t0\n")
    atmos.stop()
end

do
    print("Testing...", "gc 9: watching")
    spawn(task(function ()
        for i=1, N do
            watching('X', function () await('Y') end)
        end
        await('X')
        out(dns())
    end))
    emits(N+1)
    assertx(out(), "0\n")
    atmos.stop()
end

do
    print("Testing...", "gc 10: watching + par")
    spawn(task(function ()
        for i=1, N do
            watching('X', function ()
                par(
                    function () await('Y') end,
                    function () await('Z') end
                )
            end)
        end
        await('X')
        out(dns())
    end))
    emits(N+1)
    assertx(out(), "0\n")
    atmos.stop()
end

do
    print("Testing...", "gc 11: await or")
    spawn(task(function ()
        for i=1, N do
            await {tag='or', 'X', 'Y'}
        end
        await('X')
        out(dns())
    end))
    emits(N+1)
    assertx(out(), "0\n")
    atmos.stop()
end

do
    print("Testing...", "gc 12: await not")
    spawn(task(function ()
        for i=1, N do
            await {tag='not', 'Y'}
        end
        await('X')
        out(dns())
    end))
    emits(N+1)
    assertx(out(), "0\n")
    atmos.stop()
end

-- TOGGLE

do
    print("Testing...", "gc 13: toggle block")
    spawn(task(function ()
        for i=1, N do
            toggle('T', function () await('X') end)
        end
        await('X')
        out(dns())
    end))
    emits(N+1)
    assertx(out(), "0\n")
    atmos.stop()
end

-- ERRORS (child dies by throw/error)

do
    print("Testing...", "gc 14: catch + spawn throw")
    spawn(task(function ()
        for i=1, N do
            catch('E', function ()
                spawn(task(function () throw('E') end))
            end)
        end
        local n = dns()     -- dead, not swept yet
        await('X')
        out(n, dns())
    end))
    emits(1)
    assertx(out(), N.."\t0\n")
    atmos.stop()
end

do
    print("Testing...", "gc 15: catch + emit throw")
    spawn(task(function ()
        for i=1, N do
            catch('E', function ()
                spawn(task(function ()
                    await('X')
                    throw('E')
                end))
                await(false)
            end)
        end
        await('X')
        out(dns())
    end))
    emits(N+1)
    assertx(out(), "0\n")
    atmos.stop()
end

do
    print("Testing...", "gc 16: pcall + spawn error")
    spawn(task(function ()
        for i=1, N do
            pcall(function ()
                spawn(task(function () error('E') end))
            end)
        end
        await('X')
        out(dns())
    end))
    emits(1)
    assertx(out(), "0\n")
    atmos.stop()
end

-- POOLS

do
    print("Testing...", "gc 17: pool, normal end")
    spawn(task(function ()
        local ts = tasks()
        for i=1, N do
            spawn_in(ts, task(function () await('X') end))
        end
        await('X')
        await('X')
        out(#ts)
    end))
    emits(2)
    assertx(out(), "0\n")
    atmos.stop()
end

do
    print("Testing...", "gc 18: pool, abort(t)")
    spawn(task(function ()
        local ts = tasks()
        for i=1, N do
            local t = spawn_in(ts, task(function () await(false) end))
            abort(t)
        end
        local n = #ts       -- dead, not swept yet
        await('X')
        out(n, #ts)
    end))
    emits(1)
    assertx(out(), N.."\t0\n")
    atmos.stop()
end

do
    print("Testing...", "gc 19: pool, abort(t) in pairs")
    spawn(task(function ()
        local ts = tasks()
        for i=1, N do
            spawn_in(ts, task(function () await(false) end))
        end
        for _,t in pairs(ts) do
            abort(t)
        end
        await('X')
        out(#ts)
    end))
    emits(1)
    assertx(out(), "0\n")
    atmos.stop()
end

do
    print("Testing...", "gc 20: pool max, reuse dead slots")
    spawn(task(function ()
        local ts = tasks(1)
        local n = 0
        for i=1, N do
            if spawn_in(ts, task(function () await('X') end)) then
                n = n + 1
            end
            await('X')
        end
        out(n, #ts)     -- last child died in this reaction
    end))
    emits(N)
    assertx(out(), N.."\t1\n")
    atmos.stop()
end

do
    print("Testing...", "gc 21: abort(pool)")
    spawn(task(function ()
        local ts = tasks()
        for i=1, N do
            spawn_in(ts, task(function () await(false) end))
        end
        abort(ts)
        await('X')
        out(#ts)
    end))
    emits(1)
    assertx(out(), "0\n")
    atmos.stop()
end

do
    print("Testing...", "gc 22: pool <close> in loop")
    -- by design: closed pool is still usable, kept in parent
    spawn(task(function ()
        for i=1, N do
            local ts <close> = tasks()
            spawn_in(ts, task(function () await(false) end))
            await('X')
        end
        await('X')
        out(dns())
    end))
    emits(N+1)
    assertx(out(), N.."\n")
    atmos.stop()
end

do
    print("Testing...", "gc 23: pool in loop, no close")
    -- by design: pool lives with its task
    spawn(task(function ()
        for i=1, N do
            local ts = tasks()
            await('X')
        end
        await('X')
        out(dns())
    end))
    emits(N+1)
    assertx(out(), N.."\n")
    atmos.stop()
end

-- STOP

do
    print("Testing...", "gc 24: stop clears root")
    local t = spawn(task(function () await(false) end))
    local up = t._.up
    atmos.stop()
    assertx(#up._.dns, 0)
end
