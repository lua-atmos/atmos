local S = require "atmos.streams"
require "atmos.util"
local lanes -- lazy require in `spawn`

local M = {
    thread_modules = {}, -- requires to pass to threads
}

local task_gc

local meta_defer = {
    __close = function (t) t.f() end
}

local function _next (s, i)
    if i == s.max then
        return nil
    else
        i = i + 1
        return i, s.ts._.dns[i]
    end
end
local function _ipairs (ts)
    ts._.ing = ts._.ing + 1
    local close = setmetatable({}, {
        __close = function ()
            ts._.ing = ts._.ing - 1
            task_gc(ts)
        end
    })
    return _next, {ts=ts,max=#ts._.dns}, 0, close
end

local meta_tasks; meta_tasks = {
    __close = function (ts)
        for _,dn in ipairs(ts._.dns) do
            getmetatable(dn).__close(dn)
        end
    end,
    __len = function (ts)
        return #ts._.dns
    end,
    __pairs = _ipairs,
}
local meta_task = {
    __close = function (t)
        for _,dn in ipairs(t._.dns) do
            getmetatable(dn).__close(dn)
        end
        local st = coroutine.status(t._.th)
        if st == 'suspended' then
            assert(coroutine.close(t._.th))
        elseif st ~= 'dead' then
            t._.status = 'aborted'
        end
    end
}

local TIME = 1

local TASKS = setmetatable({
    _ = {
        up  = nil,
        dns = {},
        pin = true,
        ing = 0,
        gc  = false,
        max = nil,
        cache = setmetatable({}, {__mode='k'}),
    }
}, meta_tasks)

-------------------------------------------------------------------------------

function M.clock (t)
    assertn(2, type(t)=='table', "invalid clock : expected table")
    return {
        tag = 'clock',
        ms  = (
            (t.ms                       or 0) +
            (t.s   and t.s  *1000       or 0) +
            (t.min and t.min*1000*60    or 0) +
            (t.h   and t.h  *1000*60*60 or 0)
        ),
    }
end

-------------------------------------------------------------------------------

local function _me_ (tra, t)
    if t == TASKS then
        return nil
    elseif (getmetatable(t) == meta_tasks) or ((not tra) and t._.tra) then
        return _me_(tra, t._.up)
    else
        return t
    end
end

function M.me (tra)
    local th = coroutine.running()
    return th and TASKS._.cache[th] and _me_(tra, TASKS._.cache[th])
end

-------------------------------------------------------------------------------

function M.is (v, x)
    if v == x then
        return true
    end
    local tp = type(v)
    local mt = getmetatable(v)
    if tp == x then
        return true
    elseif tp=='string' and type(x)=='string' then
        return (string.find(v, '^'..x..'%.') == 1)
    elseif mt==meta_task and x=='task' then
        return true
    elseif mt==meta_tasks and x=='tasks' then
        return true
    elseif tp=='table' and type(x)=='string' and type(v.tag)=='string' then
        return (string.find(v.tag or '', '^'..x) == 1)
    else
        return false
    end
end

function M.status (t)
    return coroutine.status(t._.th)
end

-------------------------------------------------------------------------------

local function task_result (t, ok, err)
    if ok then
        -- no error: continue normally
        if t._.status == 'aborted' then
            -- t aborted from outside
            -- close now and continue normally
            -- could not close before b/c t was running
            -- TODO: lua5.5
            assert(coroutine.close(t._.th))
        end
    else
        coroutine.close(t._.th) -- TODO: assert fails "tasks.lua: error 2"
        error(err, 0)
    end

    if coroutine.status(t._.th) == 'dead' then
        t.ret = err
        t._.up._.gc = true
        --if t._.status ~= 'aborted' then
            local up = _me_(false, t._.up)
            if (getmetatable(t._.up) == meta_tasks) and (t._.up ~= TASKS) then
                t._.up.ret = t._.up.ret or t
                up = _me_(false, t._.up._.up)   -- await(ts) must reach parent
            end
            M.emit(false, up, t)
        --end
        meta_task.__close(t)
    end
end

task_gc = function (t)
    if t._.gc and t._.ing==0 then
        t._.gc = false
        for i=#t._.dns, 1, -1 do
            local s = t._.dns[i]
            if getmetatable(s)==meta_task and coroutine.status(s._.th)=='dead' then
                table.remove(t._.dns, i)
            end
        end
    end
end

---------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local _envs_ = {}

function M.env (e)
    _envs_[#_envs_+1] = e
    if #_envs_ == 1 then
        -- ok: first env may support any mode
    else
        local i = #_envs_
        assertn(2, _envs_[1].mode and _envs_[1].mode.primary,
            "invalid env : first env must support primary mode")
        assertn(2, _envs_[i].mode and _envs_[i].mode.secondary,
            "invalid env : non-first envs must support secondary mode")
        _envs_[1].mode.current = 'primary'
        e.mode.current = 'secondary'
    end
end

function M.defer (f)
    return setmetatable({f=f}, meta_defer)
end

local meta_throw = {}

local function trace ()
    local ret = {}
    local x = M.me(true)
    while x and x~=TASKS do
        ret[#ret+1] = {
            msg = (getmetatable(x)==meta_task and 'task') or 'tasks',
            dbg = x._.dbg,
        }
        x = x._.up
    end
    return ret
end

local function tothrow (dbg, ...)
    local err = {
        _ = {
            dbg = { file=dbg.short_src, line=dbg.currentline },
            pre = trace(),
            pos = {},
        },
        ...
    }
    return setmetatable(err, meta_throw)
end

function M.throw (...)
    return error(tothrow(debug.getinfo(2),...))
end

-- break out of an enclosing loop (every): tail call preserves the
-- caller line in the throw trace, mirroring the language atm_break
function M._break_ (...)
    return M.throw('atm-loop', ...)
end

function M.catch (...)
    local cnd = { ... }
    local blk = table.remove(cnd, #cnd)
    return (function (ok, err, ...)
        if ok then
            return ok,err,...
        elseif getmetatable(err) == meta_throw then
            local X = cnd[1]
            if false then
            elseif X == false then
                error(err, 0)
            elseif X == true then
                return false, table.unpack(err)
            elseif type(X) == 'function' then
                return (function (ok, ...)
                    if ok then
                        return false, ...
                    else
                        error(err, 0)
                    end
                end)(X(table.unpack(err)))
            else
                for i=1, #cnd do
                    if not M.is(err[i],cnd[i]) then
                        error(err, 0)
                    end
                end
                return false, table.unpack(err)
            end
        else
             error(err, 0)
        end
    end)(pcall(blk))
end

local function flatten (err)
    local str = ""
    for i,e in ipairs(err) do
        if i > 1 then
            str = str .. ", "
        end
        str = str .. tostring(e) or ('('..type(e)..')')
    end
    local ret = "==> ERROR:\n"

    for i=#err._.pos, 1, -1 do
        local t = err._.pos[i]
        ret = ret .. " |  "
        for j=1, #t do
            local e = t[j]
            ret = ret .. e.dbg.file .. ":" .. e.dbg.line .. " (" .. e.msg.. ")"
            if j < #t then
                ret = ret .. " <- "
            end
        end
        ret = ret .. "\n"
    end

    ret = ret .. " v  " .. err._.dbg.file .. ":" .. err._.dbg.line .. " (throw)"
    for i=1, #err._.pre do
        local e = err._.pre[i]
        ret = ret .. " <- "
        ret = ret .. e.dbg.file .. ":" .. e.dbg.line .. " (" .. e.msg .. ')'
    end
    ret = ret .. "\n"

    ret = ret .. "==> " .. str .. '\n'
    return ret
end

local function xcall (dbg, stk, f, ...)
    return (function (ok, err, ...)
        if ok then
            return err, ...
        end

        if type(err)=='string' and string.match(err, '^==> ERROR:') then
            -- already flatten
            error(err, 0)
        end

        if stk then
            if (getmetatable(err) ~= meta_throw) then
                local file, line, msg = string.match(err, '(.-):(%d-): (.*)')
                err = {
                    _ = {
                        dbg = { file=file or '?', line=line or '?' },
                        pre = trace(),
                        pos = {},
                    },
                    msg or err
                }
                err = setmetatable(err, meta_throw)
            end
            if getmetatable(err) == meta_throw then
                local t = trace()
                err._.pos[#err._.pos+1] = t
                table.insert(t, 1, {
                    msg = stk,
                    dbg = { file=dbg.short_src, line=dbg.currentline },
                })
            end
        end
        if stk == "loop" then
            err = flatten(err)
        end
        error(err, 0)

    end)(pcall(f, ...))
end

function M.loop (body, ...)
    assertn(2, type(body)=='function', "invalid loop : expected body function")
    return xcall(debug.getinfo(2), "loop", function (...)
        local f = body
        local _ <close> = M.defer(function ()
            M.stop()
        end)
        local t <close> = M.spawn(debug.getinfo(4), nil, false, body, ...)
        while true do
            if coroutine.status(t._.th) == 'dead' then
                break
            end
            local quit = false
            for _, env in ipairs(_envs_) do
                if env.step() then
                    quit = true
                    break
                end
            end
            if quit then
                break
            end
        end
        return t.ret
    end, ...)
end

function M.start (body, ...)
    assertn(2, type(body)=='function', "invalid start : expected body function")
    assertn(2, #_envs_==1 and _envs_[1].mode==nil, "invalid start : expected single-mode env only")
    M.spawn(debug.getinfo(2), nil, false, body, ...)
end

function M.stop ()
    meta_tasks.__close(TASKS)
    for i=#_envs_, 1, -1 do
        if _envs_[i].quit then
            _envs_[i].quit()
        end
        _envs_[i] = nil
    end
end

-------------------------------------------------------------------------------

function M.tasks (max)
    local n = max and tonumber(max) or nil
    assertn(2, (not max) or n, "invalid tasks limit : expected number")
    local up = M.me(true) or TASKS
    local dbg = debug.getinfo(2)
    local ts = {
        _ = {
            up  = up,
            dns = {},
            pin = false,
            ing = 0,
            gc  = false,
            dbg = {file=dbg.short_src, line=dbg.currentline},
            ---
            max = n,
        }
    }
    up._.dns[#up._.dns+1] = ts
    setmetatable(ts, meta_tasks)
    return ts
end

function M.task (dbg, tra, f)
    assertn(3, type(f)=='function', "invalid task : expected function")
    local f = function (...)
        local _no_tco_ <close> = nil
        return f(...)
    end
    local t = {
        _ = {
            up  = nil,
            dns = {},
            pin = false,
            ing = 0,
            gc  = false,
            dbg = {file=dbg.short_src, line=dbg.currentline},
            ---
            th  = coroutine.create(f),
            tra = tra,
            status = nil, -- aborted, toggled
            await = {
                time = 0,
            },
            ret = nil,
        }
    }
    TASKS._.cache[t._.th] = t
    setmetatable(t, meta_task)
    return t
end

function M.abort (t)
    assertn(2, getmetatable(t)==meta_task or getmetatable(t)==meta_tasks, "invalid abort : expected task")
    getmetatable(t).__close(t)
    if t._.up then
        t._.up._.gc = true
    end
    local me = M.me(true)
    if me and me._.status=='aborted' then
        -- TODO: lua5.5
        coroutine.yield()
        error "bug found"
    end
end

function M.spawn (dbg, up, tra, t, ...)
    if type(t) == 'function' then
        t = M.task(dbg, tra, t)
        if t == nil then
            return nil
        else
            return M.spawn(dbg, up, tra, t, ...)
        end
    end
    assertn(2, getmetatable(t)==meta_task, "invalid spawn : expected task prototype")
    assertn(2, t._.tra == tra, "invalid spawn : transparent modifier mismatch")

    up = up or M.me(true) or TASKS
    if getmetatable(up) == meta_tasks then
        t.pin = true
    end
    if up._.max then
        local n = #up._.dns
        if n >= up._.max then
            for _,t in ipairs(up._.dns) do
                if coroutine.status(t._.th) == 'dead' then
                    n = n - 1
                end
            end
            if n >= up._.max then
                return nil
            end
        end
    end
    up._.dns[#up._.dns+1] = t
    t._.up = assert(t._.up==nil and up)

    task_result(t, coroutine.resume(t._.th, ...))
    return t
end

-------------------------------------------------------------------------------

local function check_ret (T, ...)
    -- T = await pattern | ... = occurring event arguments
    local tp,e = table.unpack(T)
    local mte = getmetatable(...)
    -- __atmos opt-out: nil first result = not handled, fall through
    if mte and mte.__atmos then
        local t = { mte.__atmos(T, ...) }
        if t[1] ~= nil then
            return table.unpack(t)
        end
    end
    if tp == '==' then
        for i = 2, #T do
            if not _is_(select(i-1,...), T[i]) then
                return false
            end
        end
        if getmetatable(e) == meta_task then
            return true, e.ret, e
        elseif getmetatable(e) == meta_tasks then
        else
            return true, ...
        end
    else
        return false
    end
end

local function await_to_table (e, ...)
    local T = {}
    if type(e) == 'table' then
        if getmetatable(e) and getmetatable(e).__atmos then
            T = e
        elseif type(e[1]) == 'string' then
            T = { '==', table.unpack(e) }
        end
    else
        T = { '==', e, ... }
    end
    T.time = TIME
    return T
end

function M.await (awt, ...)
    -- await(stream)
    -- await(clock{...})
    -- await(f)     -- f(...)
    -- await(true/false)
    -- await(task)
    -- await('X', ...)
    -- await({'or'/'and', ...})

    local tsk = M.me(true)
    assertn(2, tsk, "invalid await : expected enclosing task", 2)
    assertn(2, awt~=nil and select('#',...)==0,
        "invalid await : invalid event pattern", 2
    )

    local mta = getmetatable(awt)

    local tag = ((type(awt) == 'table') and awt.tag) or awt

    if tag=='or' or tag=='and' then
        local fs = {}
        for i=2, #awt do
            local sub = awt[i]
            fs[#fs+1] = function () return M.await(sub) end
        end
        local f = (tag=='or' and M.par_or) or M.par_and
        return f(table.unpack(fs, 1, #awt))
    elseif tag == 'not' then
        assertn(2, #awt==2, "invalid await : too many arguments")
        while true do
            local ret = table.pack(M.par_or(function()
                M.await(awt[2])
                return false
            end, function()
                return true, M.await(true)
            end))
            if ret[1] then
                return table.unpack(ret, 2, ret.n)
            end
        end
    elseif tag == 'clock' then
        awt._ms = awt.ms
    elseif S.is(awt) then
        return M.await(spawn(function() return awt() end))
    end

    local mode = ...
    local emt = nil

    while true do
        if getmetatable(awt) == meta_tasks then
            if mode == 'all' then
                if #awt == 0 then             -- only when #awt=0
                    return awt
                end
            else
                assertn(2, mode=='any' or mode==nil,
                    "invalid await : expected 'any' or 'all'"
                )
                if #awt == 0 then             -- immediate if #awt=0
                    return nil, nil, awt
                elseif awt.ret then           -- some task terminated
                    return awt.ret.ret, awt.ret, awt
                end
            end
        elseif getmetatable(awt) == meta_task then
            if coroutine.status(awt._.th) == 'dead' then
                return awt.ret, awt
            end
        elseif mta and mta.__atmos then
            local ok, ret = mta.__atmos(awt, emt)
            if ok then
                return ret
            end
        elseif tag == 'clock' then
            if awt._ms <= 0 then
                return 'clock', -awt._ms, awt._now
            end
        elseif type(awt) == 'function' then
            local ok, ret = awt(emt)
            if ok then
                return ret
            end
        end

        local err
        err, emt = coroutine.yield()
        if err then
            error(emt, 0)
        end

        if awt == true then
            return emt
        elseif awt == false then
            -- never awakes
        elseif tag == 'clock' then
            -- test is up
            if emt.tag == 'clock' then
                awt._ms  = awt._ms - emt.ms
                awt._now = emt.now
            end
        elseif awt == emt then
            return emt
        end
    end
end

-------------------------------------------------------------------------------

local function fto (me, to)
    if to == nil then
        to = 0
    elseif to == 'task' then
        to = 0
    elseif to == 'parent' then
        to = 1
    end

    if to == 'global' then
        to = TASKS
    elseif type(to) == 'number' then
        local n = tonumber(to)
        to = me or TASKS
        while n > 0 do
            to = to._.up
            assertn(3, to~=nil, "invalid emit : invalid target")
            n = n - 1
        end
    elseif getmetatable(to)==meta_task or getmetatable(to)==meta_tasks then
        to = to
    else
        error("invalid emit : invalid target", 3)
    end

    return to
end

local function emit (time, t, ...)
    local ok, err = true, nil

    if t._.status == 'toggled' then
        -- toggled off: gate the whole subtree, unless a filter matches
        if not (t._.filter and check_ret(t._.filter, ...)) then
            return ok, err
        end
    end

    t._.ing = t._.ing + 1
    for i=1, #t._.dns do
        local dn = t._.dns[i]
        ok, err = pcall(emit, time, dn, ...)
        if not ok then
            break
        end
    end
    t._.ing = t._.ing - 1

    task_gc(t)

    if getmetatable(t) == meta_task then
        if not ok then
            if coroutine.status(t._.th) == 'suspended' then
                ok, err = coroutine.resume(t._.th, 'atm_error', err)
                if ok then
                    task_result(t, ok, err)
                end
            end
            assertn(0, ok, err) -- TODO: error in defer?
        else
            if (t._.await.time < time) and (coroutine.status(t._.th) == 'suspended') then
                task_result(t, coroutine.resume(t._.th, nil, ...))
            end
        end
    else
        assert(getmetatable(t) == meta_tasks)
        assertn(0, ok, err)
    end
end

function M.emit (stk, to, e, ...)
    TIME = TIME + 1
    local time = TIME
    local ret = xcall(debug.getinfo(2), stk and "emit", emit, time, fto(M.me(false),to), e, ...)
    local me = M.me(true)
    if me and me._.status=='aborted' then
        -- TODO: lua5.5
        coroutine.yield()   -- wait to be closed from outside
        error "bug found"
    end
    return ret
end

-------------------------------------------------------------------------------

function M.toggle (t, on, ...)
    if type(t) == 'string' then
        --@ derived: spawn; loop { await; toggle; await; toggle; }
        local e, f = t, on
        assertn(2, type(f)=='function', "invalid toggle : expected task prototype")
        local filter = table.pack(...)
        do
            local t <close> = M.spawn(debug.getinfo(2), nil, true, f)
            local _ <close> = M.spawn(debug.getinfo(2), nil, true, function ()
                while true do
                    M.await(e, false)
                    M.toggle(t, false, table.unpack(filter, 1, filter.n))
                    M.await(e, true)
                    M.toggle(t, true)
                end
            end)
            return M.await(t)
        end
    end

    assertn(2, getmetatable(t)==meta_task or getmetatable(t)==meta_tasks,
        "invalid toggle : expected task")
    assertn(2, type(on) == 'boolean', "invalid toggle : expected bool argument")
    t._.filter = nil
    if on then
        assertn(2, t._.status=='toggled', "invalid toggle : expected toggled off task")
        t._.status = nil
    else
        assertn(2, t._.status==nil --[[and coroutine.status(t._.th)=='suspended']],
            "invalid toggle : expected awaiting task")
        t._.status = 'toggled'
        -- build the filter at toggle-off time so T.time = TIME is fresh
        local filter = table.pack(...)
        if filter.n > 0 then
            t._.filter = await_to_table(table.unpack(filter, 1, filter.n))
        end
    end
end

-------------------------------------------------------------------------------

local _gen_cache = setmetatable({}, { __mode = 'k' })

function M.thread (f)
    local me = M.me(true)
    assertn(2, type(f)=='function', "invalid thread : expected body function")
    assertn(2, me, "invalid thread : expected enclosing task")

    if not lanes then   -- lazy require
        -- requires lanes installed only if uses `thread`
        lanes = require("lanes").configure()
    end

    local gen = _gen_cache[f]
    if not gen then
        gen = lanes.gen("*", function (linda, mods)
            for _,mod in ipairs(mods) do
                require(mod)
            end
            linda:send("ok", { pcall(f) })
        end)
        _gen_cache[f] = assert(gen)
    end

    local linda = lanes.linda()
    local lane = assert(gen(linda, M.thread_modules))

    local _ <close> = M.defer(function ()
        while lane.status == 'pending' do
            -- busy wait: "Not started yet. Shouldn't stay very long in that state."
        end
        assert(lane:cancel('hard', 0, true, 1))
    end)

    while true do
        local key, t = linda:receive(0, "ok")
        if key then
            if t[1] then
                return table.unpack(t, 2)
            else
                error(t[2], 0)
            end
        else
            M.await(true)
        end
    end
end

-------------------------------------------------------------------------------

--@ derived: loop { f(await(awt, payload...)) }
function M.every (...)
    assertn(2, M.me(true), "invalid every : expected enclosing task")
    local t = { ... }
    local blk = table.remove(t, #t)
    -- tag-specific catch: break exits the loop, but return (atm-func),
    -- abort, and any other throw still propagate past every
    M.catch('atm-loop', function ()
        while true do
            blk(M.await(table.unpack(t)))
        end
    end)
end

local meta_par = {
    __close = function (ts)
        for _, t in ipairs(ts) do
            meta_task.__close(t)
        end
    end
}

--@ derived: spawn each + await(false) + lifetime
function M.par (...)
    assertn(2, M.me(true), "invalid par : expected enclosing task")
    local fs = { ... }
    local ts <close> = setmetatable({}, meta_par)
    for i,f in ipairs(fs) do
        assertn(2, type(f) == 'function', "invalid par : expected task prototype")
        ts[i] = M.spawn(debug.getinfo(2), nil, true, select(i,...))
    end
    M.await(false)
end

--@ derived: throw-based race per plan §4
function M.par_or (...)
    assertn(2, M.me(true), "invalid par_or : expected enclosing task")
    local fs = { ... }
    local dbg = debug.getinfo(2)
    local trap = {}
    return (function (_, _, ...) return ... end)(M.catch(trap, function ()
        local ts <close> = setmetatable({}, meta_par)
        for i,f in ipairs(fs) do
            assertn(2, type(f) == 'function', "invalid par_or : expected task prototype")
            ts[i] = M.spawn(dbg, nil, true, function ()
                M.throw(trap, f())
            end)
        end
        M.await(false)
    end))
end

--@ derived: sequential await on each spawn
function M.par_and (...)
    assertn(2, M.me(true), "invalid par_and : expected enclosing task")
    local fs = { ... }
    local dbg = debug.getinfo(2)
    local ts <close> = setmetatable({}, meta_par)
    for i,f in ipairs(fs) do
        assertn(2, type(f) == 'function', "invalid par_and : expected task prototype")
        ts[i] = M.spawn(dbg, nil, true, f)
    end
    local rets = {}
    for i,t in ipairs(ts) do
        rets[i] = M.await(t)
    end
    return table.unpack(rets, 1, #fs)
end

--@ derived: par_or { await(awt, payload...) } with { f() }
function M.watching (...)
    assertn(2, M.me(true), "invalid watching : expected enclosing task")
    local t = { ... }
    local f = table.remove(t, #t)
    assertn(2, type(f) == 'function', "invalid watching : expected task prototype")
    return M.par_or(
        function () return M.await(table.unpack(t)) end,
        f
    )
end

return M
