local S = require "streams"

function S.fr_awaits (...)
    local args = { ... }
    return function ()
        return await(table.unpack(args))
    end
end

function S.fr_task (t)
    local ok = false
    return function ()
        if not ok then
            ok = true
            local t <close> = t
            return await(t)
        end
    end
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
    local mt = getmetatable(t)
    mt.__index = getmetatable(s1).__index
    mt.__call = function (t)
        local _,v = await(n)
        return v
    end
    return t
end

return S
