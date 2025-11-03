local atmos = require "atmos"
require "atmos.util"

local SDL = require "SDL"
local IMG = require "SDL.image"
local TTF = require "SDL.ttf"
local MIX = require "SDL.mixer"

assert(SDL.init())
assert(IMG.init())
assert(TTF.init())
assert(MIX.init())
MIX.openAudio(44100, SDL.audioFormat.S16, 2, 1024);

local M = {
    mpf = 0, --40,   -- 0: as fast as possible
    now = 0,
    ren = nil,
}

local MS = M.mpf

local meta = {
    __atmos = function (awt, e)
        if e.type ~= awt[1] then
            return false
        elseif (e.type==SDL.event.KeyDown or e.type==SDL.event.KeyUp) and type(awt[2])=='string' then
            return (awt[2] == e.name), e, e
        elseif type(awt[2]) == 'function' then
            return awt[2](e), e
        else
            return true, e, e
        end
    end
}

function M.ints (inp)
    local out = {}
    for k,v in pairs(inp) do
        if type(v) == 'number' then
            out[k] = math.floor(v)
        end
    end
    return out
end

function M.point_vs_rect (p, r)
    return SDL.hasIntersection(M.ints(r), M.ints{ x=p.x, y=p.y, w=1, h=1 })
end

function M.rect_vs_rect (r1, r2)
    return SDL.hasIntersection(M.ints(r1), M.ints(r2))
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

    local old = SDL.getTicks()
    local e = SDL.waitEvent(MS)
    local cur = SDL.getTicks()

    if M.mpf == 0 then
        local dt = (cur - M.now)
        M.now = cur
        emit('clock', dt, M.now)
    else
        MS = MS - (cur-old)
        if MS <= 0 then
            MS = M.mpf + MS
            M.now = cur
            emit('clock', M.mpf, M.now)
        end
    end

    if e then
        if (e.type==SDL.event.KeyDown or e.type==SDL.event.KeyUp) then
            e.name = SDL.getKeyName(e.keysym.sym)
        end
        emit(setmetatable(e, meta))
        if e.type == SDL.event.Quit then
            return true
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

function M.close ()
    MIX.quit()
    TTF.quit()
    IMG.quit()
    SDL.quit()
end

atmos.env(M)

return M
