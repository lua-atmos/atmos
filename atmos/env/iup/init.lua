local atmos = require "atmos"
require "atmos.util"

package.cpath = package.cpath .. ';/usr/lib64/libiuplua54.so'
local iup = require("iuplua")

-------------------------------------------------------------------------------

local function iup_action (self, ...)
    emit(self, 'action', ...)
end

local function iup_value (self, ...)
    emit(self, 'value', ...)
end

local iup_button = iup.button
function iup.button (...)
    local h = iup_button(...)
    h.action = iup_action
    return h
end

local iup_text = iup.text
function iup.text (...)
    local h = iup_text(...)
    h.valuechanged_cb = iup_value
    return h
end

local iup_list = iup.list
function iup.list (...)
    local h = iup_list(...)
    h.valuechanged_cb = iup_value
    return h
end

-------------------------------------------------------------------------------

local M = {
}

function M.init (on)
    if on then
        assert(iup.MainLoopLevel() == 0)
        local timer = iup.timer{time=100}
        function timer:action_cb()
            emit(clock{ms=100})
            return iup.DEFAULT
        end
        timer.run = "YES"
    else
        iup.Close()
    end
end

M.loop = iup.MainLoop

M.env = {
    init = M.init,
    loop = M.loop,
}

function M.call (body)
    return atmos.call(M.env, function ()
        body()
        iup.ExitLoop()
    end)
end

call = M.call

return M
