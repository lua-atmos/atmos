local S = require "streams"

local n = 0
local function N ()
    n = n + 1
    return 'atmos.streams.' .. n
end

-------------------------------------------------------------------------------

local function fr_await (t)
    return await(table.unpack(t.args))
end

local function fr_spawn (t)
    local x <close> = spawn(task(t.T), table.unpack(t.args))
    return await(x) or false
end

function S.fr_await (...)
    local T = select(1, ...)
    local t
    if type(T) == 'function' then
        t = {
            T    = T,
            args = { select(2,...) },
            f    = fr_spawn,
        }
    else
        t = {
            args = { ... },
            f    = fr_await,
        }
    end
    return setmetatable(t, S.mt)
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

function S.emitter (s, tgt, as)
    if as == nil then
        tgt, as = nil, tgt
    end
    return s:tap(function (v) emit_in(tgt, {tag=as, v}) end)
end

-------------------------------------------------------------------------------

function S.Debounce (n, src, fctl)
    local trap = {}
    while true do
        local e = await(src)
        catch(trap, function()
            while true do
                e = par_or (
                    function()
                        return await(src)
                    end,
                    function()    -- bounced
                        local ctl <close> = fctl()
                        ctl()
                        throw(trap)                 -- debounced
                    end
                )
            end
        end)
        emit_in(1, {tag=n, e})
    end
end

local function debounce (t)
    local e = await(t.n)
    return e[1]
end

local function close (t)
    local _ <close> = t.tsk
end

function S.debounce (src, fctl)
    local n = N()
    local t = {
        n   = n,
        tsk = spawn(task(S.Debounce), n, src, fctl),
        f   = debounce,
        clo = close,
    }
    return setmetatable(t, S.mt)
end

-------------------------------------------------------------------------------

function S.Buffer (n, src, ctl)
    local ctl <close> = ctl
    local trap = {}
    while true do
        local ret = {}
        catch(trap, function()
            while true do
                ret[#ret+1] = par_or (
                    function ()
                        return await(src)   -- buffered
                    end,
                    function()
                        await(ctl)
                        throw(trap)         -- released
                    end
                )
            end
        end)
        emit_in(1, {tag=n, ret})
    end
end

local function buffer (t)
    local e = await(t.n)
    return e[1]
end

local function close (t)
    local _ <close> = t.tsk
end

function S.buffer (src, ctl)
    local n = N()
    local t = {
        n   = n,
        tsk = spawn(task(S.Buffer), n, src, ctl),
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
        emit_in(3, {tag=n, v})
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
        spawn_in(tsks, task(T), n, s)
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
    local e = await(t.n)
    return e[1]
end

function S.par (...)
    local n = N()
    local tsks = tasks()
    for i=1, select('#',...) do
        local s = select(i, ...)
        spawn_in(tsks, task(T), n, s)
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
        tsk  = spawn(task(TT), n, tsks, ss),
        f    = par,
        clo  = clo_tsk,
    }
    return setmetatable(t, S.mt)
end

-------------------------------------------------------------------------------

local function paror (t)
    -- await{'or',...} forwards the winner's values: event n -> (n,payload),
    -- pool tsks -> (ret,task,ts); pool win (3rd value is the pool) ends stream
    local e,_,ts = await {tag='or', t.n, {tag='tasks', mode='any', tasks=t.tsks}}
    if ts == t.tsks then
        return nil
    end
    return e[1]
end

function S.paror (...)
    local n = N()
    local tsks = tasks()
    for i=1, select('#',...) do
        local s = select(i, ...)
        spawn_in(tsks, task(T), n, s)
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
        tsk  = spawn(task(TT), n, tsks, ss),
        f    = paror,
        clo  = clo_tsk,
    }
    return setmetatable(t, S.mt)
end

-------------------------------------------------------------------------------

return S
