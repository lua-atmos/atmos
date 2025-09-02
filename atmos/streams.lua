local S = require "streams"

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
    x = s:tap(function (v) emit_in(3, as or x, v) end)
    return x
end

-------------------------------------------------------------------------------

function S.Debounce (src, ctl)
    local e = await(src)
    catch('X', function()
        while true do
            e = watching(src, function()    -- bounced
                await(ctl)
                throw 'X'                   -- debounced
            end)
        end
    end)
    return e
end

function S.debounce (src, ctl)
    src, ctl = src:emitter(), ctl:emitter()
    local t = spawn(function()
        local src <close> = src
        local ctl <close> = ctl
        S.xpar(S.from{src,ctl}):to()
    end)
    local deb = S.fr_spawns(S.Debounce, src, ctl)
    deb.close = function ()
        local _ <close> = t
    end
    return deb
end

-------------------------------------------------------------------------------

function S.Buffer (src, ctl)
    local ret = {}
    local e = await(src)
    ret[#ret+1] = e
    catch('X', function()
        while true do
            e = watching(src, function()    -- bounced
                await(ctl)
                throw 'X'                   -- debounced
            end)
            ret[#ret+1] = e
        end
    end)
    return ret
end

function S.buffer (src, ctl)
    src, ctl = src:emitter(), ctl:emitter()
    local t = spawn(function()
        local src <close> = src
        local ctl <close> = ctl
        S.xpar(S.from{src,ctl}):to()
    end)
    local deb = S.fr_spawns(S.Buffer, src, ctl)
    deb.close = function ()
        local _ <close> = t
    end
    return deb
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local N = 0

local function T (n, s)
    while true do
        local v = s()
        if v == nil then
            return
        end
        emit_in(3, n, v)
    end
end

local function TT (ts, ss, n)
    local ss <close> = ss
    local ts <close> = ts
    while true do
        local s = ss()
        if s == nil then
            await(false)
        end
        spawn_in(ts, T, n, s)
    end
end

local function close (t)
    local _ <close> = t.t
end

-------------------------------------------------------------------------------

local function xpar (t)
    local _,v = await(t.n)
    return v
end

function S.xpar (ss)
    N = N + 1
    local n = N
    local ts = tasks()
    local t = {
        n  = n,
        ts = ts,
        t  = spawn(TT, ts, ss, n),
        f  = xpar,
        close = close,
    }
    return setmetatable(t, S.mt)
end

-------------------------------------------------------------------------------

local function xparor (t)
    local x,v = await(_or_(t.n,t.ts))
    if v == t.ts then
        return nil
    end
    return v
end

function S.xparor (ss)
    N = N + 1
    local n = N
    local ts = tasks()
    local t = {
        n  = n,
        ts = ts,
        t  = spawn(TT, ts, ss, n),
        f  = xparor,
        close = close,
    }
    return setmetatable(t, S.mt)
end

-------------------------------------------------------------------------------

return S
