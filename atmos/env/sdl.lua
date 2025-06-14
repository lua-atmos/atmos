local SDL = require "SDL"

local M = {}

local meta = {
    __atmos = function (e, awt)
        return e.type == awt.e
    end
}

local MS_PER_FRAME = 40
local old = SDL.getTicks() - MS_PER_FRAME
local ms = 0

function M.point_vs_rect (p, r)
    return SDL.hasIntersection(r, { x=p.x, y=p.y, w=1, h=1 })
end

function M.loop (ren)
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
                emit(clock{ms=MS_PER_FRAME})
                emit('step', MS_PER_FRAME)
            end
        end
        if ren then
            ren:clear()
        end
        emit('SDL.Draw')
        if ren then
            ren:present()
        end
    end
end

return M
