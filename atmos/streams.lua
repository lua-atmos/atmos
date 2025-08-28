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

function S.merge (s1, s2)
    local t = spawn(function()
        return par_or (
            function() return s1() end,
            function() return s2() end
        )
    end)
    return function ()
        return await(t)
    end
end

return S
