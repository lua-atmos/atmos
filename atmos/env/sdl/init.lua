local atmos = require "atmos"
local SDL = require "SDL"
require "atmos.util"

local M = {
    ren = nil,
}

local meta = {
    __atmos = function (awt, e)
        if e.type ~= awt[1] then
            return false
        elseif (e.type==SDL.event.KeyDown or e.type==SDL.event.KeyUp) and type(awt[2])=='string' then
            return (awt[2] == e.name), e
        elseif type(awt[2]) == 'function' then
            return awt[2](e)
        else
            return true, e
        end
    end
}

local MS_PER_FRAME = 40
local old = SDL.getTicks() - MS_PER_FRAME
local ms = 0

function M.point_vs_rect (p, r)
    return SDL.hasIntersection(r, { x=p.x, y=p.y, w=1, h=1 })
end

function M.rect_vs_rect (r1, r2)
    return SDL.hasIntersection(r1, r2)
end

function M.evt_vs_key (e, key)
    assert(e.type == SDL.event.KeyDown)
    return key == SDL.getKeyName(e.keysym.sym)
end

function M.pct_to_pos (x, y, r)
    local w,h = WIN:getSize()
    r = r or { x=w/2, y=h/2, w=w, h=h }
    return {
        x = math.floor((r.x-r.w/2) + (r.w*x/100)),
        y = math.floor((r.y-r.h/2) + (r.h*y/100)),
    };
end

function M.rect (pos, dim)
    return {
        x = math.floor(pos.x - (dim.w/2)),
        y = math.floor(pos.y - (dim.h/2)),
        w = dim.w,
        h = dim.h,
    }
end

function M.write (fnt, str, pos)
    local sfc = assert(fnt:renderUtf8(str, "blended", {r=255,g=255,b=255}))
    local tex = assert(REN:createTextureFromSurface(sfc))
    REN:copy(tex, nil, M.rect(pos, totable('w','h',sfc:getSize())))
end

local f
function M.play (wav)
    f = assert(MIX.loadWAV(wav))
    f:playChannel(1,0)
end

function M.step ()
    local e = SDL.waitEvent(ms)
    if e then
        if (e.type==SDL.event.KeyDown or e.type==SDL.event.KeyUp) then
            e.name = SDL.getKeyName(e.keysym.sym)
        end
        emit(setmetatable(e, meta))
        if e.type == SDL.event.Quit then
            return true
        end
    else
        local cur = SDL.getTicks()
        if (cur - old) >= MS_PER_FRAME then
            old = cur
            emit(clock{ms=MS_PER_FRAME})
            emit('sdl.step', MS_PER_FRAME)
        end
    end
    if M.ren then
        M.ren:setDrawColor(0x000000)
        M.ren:clear()
    end
    emit('sdl.draw')
    if M.ren then
        M.ren:present()
    end
end

M.env = {
    init = function () end,
    step = M.step,
}

function M.call (ren, body)
    M.ren = ren
    return atmos.call(M.env, body)
end

call = M.call

return M
