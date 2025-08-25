local S = require "streams"

function S.fr_await (...)
    local args = { ... }
    return function ()
        return await(table.unpack(args))
    end
end

function S.fr_task (...)
    local args = { ... }
    return function ()
        local t <close> = spawn(table.unpack(args))
        return await(t)
    end
end

return S
