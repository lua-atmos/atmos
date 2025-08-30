local S = require "streams"

-------------------------------------------------------------------------------

local function fr_awaits (t)
    return await(table.unpack(t.args))
end

function S.fr_awaits (...)
    local t = {
        args = { ... },
        f    = fr_awaits,
    }
    return setmetatable(t, S.mt)
end

-------------------------------------------------------------------------------

local function fr_spawn (t)
    if not t.ok then
        t.ok = true
        local x <close> = spawn(t.T, table.unpack(t.args))
        return await(x)
    end
end

function S.fr_spawn (T, ...)
    local t = {
        T    = T,
        args = { ... },
        ok   = false,
        f    = fr_spawn,
    }
    return setmetatable(t, S.mt)
end

-------------------------------------------------------------------------------

local N = 0

local function T (n, s)
    while true do
        local v = s()
        if v == nil then
            return
        end
        emit_in(2, n, v)
    end
end

local function par (t)
    local _,v = await(t.n)
    return v
end

function S.par (s1, s2)
    N = N + 1
    local n = N
    local t = {
        n = n,
        t = spawn(function()
            local t1 <close> = spawn(T, n, s1)
            local t2 <close> = spawn(T, n, s2)
            await(false)
        end),
        f = par,
    }
    return setmetatable(t, S.mt)
end

function S.paror (s1, s2)
    N = N + 1
    local n = N
    local t = {
        n = n,
        t = spawn(function()
            local t1 <close> = spawn(T, n, s1)
            local t2 <close> = spawn(T, n, s2)
            await(_or_(t1,t2))
        end),
        f = par,
    }
    return setmetatable(t, S.mt)
end

-------------------------------------------------------------------------------

return S
