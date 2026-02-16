local atmos = require "atmos"

local M = {
    now = 0,
}

-- JS_now() and JS_close() must be set by the JS host before start().

function M.open ()
    M.now = JS_now()
end

function M.close ()
    JS_close()
end

atmos.env(M)

return M
