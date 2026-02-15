local atmos = require "atmos"

local M = {
    now = 0,
    running = false,
}

-- js_now() must be set by the JS host before calling start().
-- It returns the current time in milliseconds (e.g., Date.now()).

function M.open ()
    M.now = js_now()
    M.running = true
end

function M.tick ()
    local now = js_now()
    local dt = now - M.now
    if dt > 0 then
        M.now = now
        emit('clock', dt, now)
    end
end

function M.close ()
    M.running = false
end

M.env = {
    open  = M.open,
    close = M.close,
}

atmos.env(M.env)

return M
