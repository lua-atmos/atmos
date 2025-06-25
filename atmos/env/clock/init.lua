local atmos = require "atmos"

local M = {}

local old

function M.step ()
    local now = math.floor(os.clock() * 1000)
    if now > old then
        emit(clock { ms=now-old })
        old = now
    end
end

function M.loop (body)
    old = math.floor(os.clock() * 1000)
    return atmos.loop({M.step}, body)
end

loop = M.loop

return M
