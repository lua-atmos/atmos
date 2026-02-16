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

function M.close ()
    M.running = false
    JS_close()
end

atmos.env(M)

return M
