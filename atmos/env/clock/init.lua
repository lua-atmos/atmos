local atmos = require "atmos"

local M = {
    now = 0,
}

local old = math.floor(os.clock() * 1000)

function M.step ()
    local now = math.floor(os.clock() * 1000)
    if now > old then
        local cur = M.env.mode and M.env.mode.current
        if cur ~= 'secondary' then
            emit('clock', (now-old), now)
        end
        M.now = now
        old = now
    end
end

M.env = {
    mode = { primary=true, secondary=true },
    step = M.step,
}

atmos.env(M.env)

return M
