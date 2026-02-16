local atmos = require "atmos"

local M = {
    now = 0,
    running = false,
}

-- JS_now() and JS_close() must be set by the JS host before start().

function M.open ()
    M.now = JS_now()
    M.running = true
end

function M.step ()
    local now = JS_now()
    local dt = now - M.now
    if dt > 0 then
        M.now = now
        emit('clock', dt, now)
    end
end

function M.close ()
    M.running = false
    JS_close()
end

atmos.env(M)

return M
