local atmos = require "atmos"
require "atmos.util"

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
    now = 0,
}

local timer = iup.timer{time=100}
function timer:action_cb()
    return iup.DEFAULT
end
timer.run = "YES"

M.env = {
    step = function ()
        if iup.LoopStepWait() == iup.CLOSE then
            return true
        end
        local now = math.floor(os.clock() * 1000)
        if now > M.now then
            emit('clock', now - M.now, now)
            M.now = now
        end
    end,
    close = iup.Close,
}

atmos.env(M.env)

return M
