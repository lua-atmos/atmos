local atmos = require "atmos"
local pico  = require "pico"

pico.zet = pico.set     -- because of `set` keyword in Atmos

local M = {
    mpf = 25,   -- 0: as fast as possible
    now = 0,
    ren = nil,
    mode = { primary=true, secondary=true },
}

function M.open ()
    pico.init(true)
    pico.set.expert(true)
end

local MS = M.mpf

local meta = {
    __atmos = function (awt, e)
        if not _is_(e.tag, awt[1]) then
            return false
        elseif _is_(e.tag, 'key') and type(awt[2])=='string' then
            if awt[2] ~= e.key then
                return false
            end
        elseif _is_(e.tag, 'mouse.button') and type(awt[2])=='string' then
            if awt[2] ~= e.but then
                return false
            end
        end

        local f = awt[#awt]
        if type(f) == 'function' then
            if not f(e) then
                return false
            end
        end

        return true, e, e
    end
}

function M.close ()
    pico.init(false)
end

function M.step ()
    local mcur = M.mode and M.mode.current

    local old = pico.get.ticks()
    local e = pico.input.event((mcur == 'secondary') and 0 or MS)
    local cur = pico.get.ticks()

    if mcur ~= 'secondary' then
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
    end

    if e then
        emit(setmetatable(e, meta))
        if e.tag == 'quit' then
            return true
        end
    end
    pico.output.clear()
    emit('draw')
    pico.output.present()
end

atmos.env(M)

return M
