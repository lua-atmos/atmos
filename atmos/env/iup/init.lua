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

-------------------------------------------------------------------------------

local M = {
}

function M.step ()
    assert(iup.MainLoopLevel() == 0)
    iup.MainLoop()
    return true
end

function M.call (body)
    return atmos.call({M.step}, body)
end

call = M.call

return M
