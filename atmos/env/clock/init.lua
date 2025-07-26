local atmos = require "atmos"

local M = {}

local old

function M.init (on)
    if on then
        old = math.floor(os.clock() * 1000)
    end
end

function M.step ()
    local now = math.floor(os.clock() * 1000)
    if now > old then
        emit(clock { ms=now-old })
        old = now
    end
end

M.env = {
    init = M.init,
    step = M.step,
}

atmos.env(M.env)

return M
