local SDL = require "SDL"

local env = {}

local meta = {
    __atmos = function (e, awt)
        return e.type == awt.e
    end
}

local MS_PER_FRAME = 40
local old = SDL.getTicks() - MS_PER_FRAME
local ms = 0

function env.loop ()
    while true do
        local e = SDL.waitEvent(ms)
        if e then
            emit(setmetatable(e, meta))
            if e.type == SDL.event.Quit then
                break
            end
        else
            local cur = SDL.getTicks()
            if (cur - old) >= MS_PER_FRAME then
                old = cur
                emit('step', MS_PER_FRAME)
            end
        end
        emit('SDL.Draw')
    end
end

return env
