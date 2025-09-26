local S = require "streams"

local n = 0
local function N ()
    n = n + 1
    return 'atmos.streams.' .. n
end

local from = S.from

function S.from (v, ...)
    if _is_(v, 'clock') then
        return S.fr_awaits(v, ...)
    end
    return from(v, ...)
end

-------------------------------------------------------------------------------

local function fr_awaits (t)
    return await(table.unpack(t.args))
end

function S.fr_awaits (...)
    local t = {
        args = { ... },
        f    = fr_awaits,
    }
    return setmetatable(t, S.mt)
end

-------------------------------------------------------------------------------

local function fr_spawns (t)
    local x <close> = spawn(t.T, table.unpack(t.args))
    return await(x)
end

function S.fr_spawns (T, ...)
    local t = {
        T    = T,
        args = { ... },
        f    = fr_spawns,
    }
    return setmetatable(t, S.mt)
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

function S.emitter (s, as)
    local x
    x = s:tap(function (v) emit_in(3, as, v) end)
    return x
end

-------------------------------------------------------------------------------

function S.Debounce (n, src, fctl)
    while true do
        local e = await(src)
        catch('X', function()
            while true do
                e = par_or (
                    function()
                        return await(src)
                    end,
                    function()    -- bounced
                        local ctl <close> = fctl()
                        ctl()
                        throw 'X'                   -- debounced
                    end
                )
            end
        end)
        emit_in(1, n, e)
    end
end

local function debounce (t)
    local _,v = await(t.n)
    return v
end

local function close (t)
    local _ <close> = t.tsk
end

function S.debounce (src, fctl)
    local n = N()
    local t = {
        n   = n,
        tsk = spawn(S.Debounce, n, src, fctl),
        f   = debounce,
        clo = close,
    }
    return setmetatable(t, S.mt)
end

-------------------------------------------------------------------------------

function S.Buffer (n, src, ctl)
    local ctl <close> = ctl
    while true do
        local ret = {}
        catch('X', function()
            while true do
                ret[#ret+1] = par_or (
                    function ()
                        return await(src)   -- buffered
                    end,
                    function()
                        await(ctl)
                        throw 'X'           -- released
                    end
                )
            end
        end)
        emit_in(1, n, ret)
    end
end

local function buffer (t)
    local _,v = await(t.n)
    return v
end

local function close (t)
    local _ <close> = t.tsk
end

function S.buffer (src, ctl)
    local n = N()
    local t = {
        n   = n,
        tsk = spawn(S.Buffer, n, src, ctl),
        f   = buffer,
        clo = close,
    }
    return setmetatable(t, S.mt)
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local function T (n, s)
    while true do
        local v = s()
        if v == nil then
            return
        end
        emit_in(3, n, v)
    end
end

local function TT (n, tsks, ss)
    local ss <close> = ss
    local tsks <close> = tsks
    while true do
        local s = ss()
        if s == nil then
            await(false)
        end
        spawn_in(tsks, T, n, s)
    end
end

local function clo_tsk (t)
    local _ <close> = t.tsk
end

local function clo_tsks (t)
    local _ <close> = t.tsks
end

-------------------------------------------------------------------------------

local function par (t)
    local _,v = await(t.n)
    return v
end

function S.par (...)
    local n = N()
    local tsks = tasks()
    for i=1, select('#',...) do
        local s = select(i, ...)
        spawn_in(tsks, T, n, s)
    end
    local t = {
        n    = n,
        tsks = tsks,
        f    = par,
        clo  = clo_tsks,
    }
    return setmetatable(t, S.mt)
end

function S.xpar (ss)
    local n = N()
    local tsks = tasks()
    local t = {
        n    = n,
        tsks = tsks,
        tsk  = spawn(TT, n, tsks, ss),
        f    = par,
        clo  = clo_tsk,
    }
    return setmetatable(t, S.mt)
end

-------------------------------------------------------------------------------

local function paror (t)
    local x,v = await(_or_(t.n,t.tsks))
    if v == t.tsks then
        return nil
    end
    return v
end

function S.paror (...)
    local n = N()
    local tsks = tasks()
    for i=1, select('#',...) do
        local s = select(i, ...)
        spawn_in(tsks, T, n, s)
    end
    local t = {
        n    = n,
        tsks = tsks,
        f    = paror,
        clo  = clo_tsks,
    }
    return setmetatable(t, S.mt)
end

function S.xparor (ss)
    local n = N()
    local tsks = tasks()
    local t = {
        n    = n,
        tsks = tsks,
        tsk  = spawn(TT, n, tsks, ss),
        f    = paror,
        clo  = clo_tsk,
    }
    return setmetatable(t, S.mt)
end

-------------------------------------------------------------------------------

return S
