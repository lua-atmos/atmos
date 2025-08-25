local S = require "streams"

function S.fr_await (...)
    local args = { ... }
    return function ()
        return await(table.unpack(args))
    end
end

return S
