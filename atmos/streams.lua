local S = require "streams"

local from = S.from

function S.from (v)
    if _is_(v, 'clock') then
        return S.fr_awaits(v)
    end
    return from(v)
end

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

local function fr_spawns (t)
    local x <close> = spawn(t.T, table.unpack(t.args))
    return await(x)
end

function S.fr_spawns (T, ...)
    local t = {
        T    = T,
        args = { ... },
        f    = fr_spawns,
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
    local x,v = await(_or_(t.n,t.t))
    if _is_(x, 'task') then
        return nil
    end
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
