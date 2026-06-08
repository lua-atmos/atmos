local atmos = require "atmos"

local M = {
    now = 0,
}

local old = math.floor(os.clock() * 1000000)

function M.step ()
    local now = math.floor(os.clock() * 1000000)
    if now > old then
        emit {
            tag = 'clock',
            us  = now - old,
            now = now,
        }
        M.now = now
        old = now
    end
end

M.env = {
    step = M.step,
}

atmos.env(M.env)

return M
