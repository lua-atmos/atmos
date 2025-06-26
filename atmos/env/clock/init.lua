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

function M.call (body)
    old = math.floor(os.clock() * 1000)
    return atmos.call({M.step}, body)
end

call = M.call

return M
