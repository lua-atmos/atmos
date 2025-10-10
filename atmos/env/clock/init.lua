local atmos = require "atmos"

local M = {}

local old = math.floor(os.clock() * 1000)

function M.step ()
    local now = math.floor(os.clock() * 1000)
    if now > old then
        emit('clock', (now-old), now)
        old = now
    end
end

M.env = {
    init = M.init,
    step = M.step,
}

atmos.env(M.env)

return M
