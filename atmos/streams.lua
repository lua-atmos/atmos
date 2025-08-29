local S = require "streams"

function S.fr_awaits (...)
    local args = { ... }
    local f = function ()
        return await(table.unpack(args))
    end
    return setmetatable({f=f}, S.mt)
end

function S.fr_spawn (T, ...)
    local args = { ... }
    local ok = false
    local f = function ()
        if not ok then
            ok = true
            local t <close> = spawn(T, table.unpack(args))
            return await(t)
        end
    end
    return setmetatable({f=f}, S.mt)
end

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

function S.par (s1, s2)
    local n = N
    N = N + 1
    local t = spawn(function()
        local t1 <close> = spawn(T, n, s1)
        local t2 <close> = spawn(T, n, s2)
        await(false)
    end)
    local f = function (t)
        local _,v = await(n)
        return v
    end
    return setmetatable({f=f}, S.mt)
end

return S
