local atmos = require "atmos"
require "atmos.util"

package.cpath = package.cpath .. ';/usr/lib64/libiuplua54.so'
local iup = require("iuplua")

-------------------------------------------------------------------------------

local meta = {
    __atmos = function (awt, ...)
        for i,x in ipairs(awt) do
            local y = select(i, ...)
            if i == 1 then
                local mt = getmetatable(x)
                if mt and mt.__index then
                    x = x.atm
                end
            end
            if x ~= y then
                return false
            end
        end
        return true
    end
}

local function iup_action (self, ...)
    emit(self.atm, 'action', ...)
end

local function iup_value (self, ...)
    emit(self.atm, 'value', ...)
end

local iup_button = iup.button
function iup.button (...)
    local h = iup_button(...)
    h.atm = setmetatable({}, meta)
    h.action = iup_action
    return h
end

local iup_text = iup.text
function iup.text (...)
    local h = iup_text(...)
    h.atm = setmetatable({}, meta)
    h.valuechanged_cb = iup_value
    return h
end

local iup_list = iup.list
function iup.list (...)
    local h = iup_list(...)
    h.atm = setmetatable({}, meta)
    h.valuechanged_cb = iup_value
    return h
end

-------------------------------------------------------------------------------

local M = {
}

do
    assert(iup.MainLoopLevel() == 0)
    local timer = iup.timer{time=100}
    function timer:action_cb()
        emit(clock{ms=100})
        return iup.DEFAULT
    end
    timer.run = "YES"
end

M.env = {
    loop  = iup.MainLoop,
    stop  = function ()
        iup.ExitLoop()
    end,
    close = function ()
        iup.Close()
    end,
}

atmos.env(M.env)

return M
