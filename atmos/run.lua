local S = require "atmos.streams"
require "atmos.util"

local run = {}

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

local function _me_ (tra, t)
    if t == TASKS then
        return nil
    elseif (getmetatable(t) == meta_tasks) or ((not tra) and t._.tra) then
        return _me_(tra, t._.up)
    else
        return t
    end
end

function run.me (tra)
    local th = coroutine.running()
    return th and TASKS._.cache[th] and _me_(tra, TASKS._.cache[th])
end

function run.is (v, x)
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
    elseif tp=='table' and type(x)=='string' then
        return (string.find(v.tag or '', '^'..x) == 1)
    else
        return false
    end
end

function run.status (t)
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
            run.emit(false, up, t)
            if (getmetatable(t._.up) == meta_tasks) and (t._.up ~= TASKS) then
                local up = _me_(false, t._.up._.up)
                run.emit(false, up, t._.up, t)
            end
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

function run.env (e)
    if e.mode == nil then
        -- no mode: single-env only, cannot combine with others
        assertn(2, #_envs_ == 0,
            "invalid env : single-env only (mode not set)")
        _envs_[1] = e
        return
    end
    assertn(2, #_envs_ == 0 or _envs_[1].mode,
        "invalid env : previous env is single-env only (mode not set)")
    _envs_[#_envs_+1] = e
    if #_envs_ == 2 then
        local first = _envs_[1]
        assertn(2, first.mode.primary,
            "invalid env : primary mode not supported")
        first.mode.current = 'primary'
    end
    if #_envs_ >= 2 then
        assertn(2, e.mode.secondary,
            "invalid env : secondary mode not supported")
        e.mode.current = 'secondary'
    end
end

function run.close ()
    meta_tasks.__close(TASKS)
end

function run.defer (f)
    return setmetatable({f=f}, meta_defer)
end

local meta_throw = {}

local function trace ()
    local ret = {}
    local x = run.me(true)
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

function run.throw (...)
    return error(tothrow(debug.getinfo(2),...))
end

function run.catch (...)
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
                    if not run.is(err[i],cnd[i]) then
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

function run.loop (body, ...)
    assertn(2, type(body) == 'function',
        "invalid loop : expected body function")
    local body = function (...)
        return (function (...) return ... end)(body(...))
    end
    return xcall(debug.getinfo(2), "loop", function (...)
        local _ <close> = run.defer(function ()
            run.stop()
        end)
        for _, env in ipairs(_envs_) do
            if env.open then env.open() end
        end
        local t <close> = run.spawn(debug.getinfo(4), nil, false, body, ...)
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

function run.start (body, ...)
    assertn(2, type(body) == 'function',
        "invalid start : expected body function")
    local body = function (...)
        return (function (...) return ... end)(body(...))
    end
    assertn(2, #_envs_ == 1,
        "invalid start : expected single env")
    assertn(2, _envs_[1].mode == nil,
        "invalid start : expected env with mode=nil")
    if _envs_[1].open then _envs_[1].open() end
    run.spawn(debug.getinfo(2), nil, false, body, ...)
end

function run.stop ()
    run.close()
    for i=#_envs_, 1, -1 do
        if _envs_[i].close then
            _envs_[i].close()
        end
        _envs_[i] = nil
    end
end

-------------------------------------------------------------------------------

function run.tasks (max)
    local n = max and tonumber(max) or nil
    assertn(2, (not max) or n, "invalid tasks limit : expected number")
    local up = run.me(true) or TASKS
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

function run.task (dbg, tra, f)
    assertn(3, type(f)=='function', "invalid task : expected function")
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

function run.spawn (dbg, up, tra, t, ...)
    if type(t) == 'function' then
        t = run.task(dbg, tra, t)
        if t == nil then
            return nil
        else
            return run.spawn(dbg, up, tra, t, ...)
        end
    end
    assertn(2, getmetatable(t)==meta_task, "invalid spawn : expected task prototype")
    assertn(2, t._.tra == tra, "invalid spawn : transparent modifier mismatch")

    up = up or run.me(true) or TASKS
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

local function check_task_ret (t)
    if t.tag == '_==_' then
        if (getmetatable(t[1]) == meta_task) and (coroutine.status(t[1]._.th) == 'dead') then
            return true, t[1].ret, t[1]
        else
            return false
        end
    elseif t.tag == '_or_' then
        for _,x in ipairs(t) do
            local chk,ret = check_task_ret(x)
            if chk then
                return chk, ret
            end
        end
        return false
    elseif t.tag == '_and_' then
        local rets = {}
        for i,x in ipairs(t) do
            local chk,ret = check_task_ret(x)
            if chk then
                t[i] = { tag='_ok_', ret }
                rets[#rets+1] = ret
            end
        end
        if #rets == #t then
            return true, rets
        else
            return false
        end
    else
        return false
    end
end

local function check_ret (awt, ...)
    -- awt = await pattern | ... = occurring event arguments
    local e = awt[1]
    local mta = getmetatable(awt)
    local mte = getmetatable(...)
    if awt.tag == '_or_' then
        for _, x in ipairs(awt) do
            local vs = { check_ret(x, ...) }
            if vs[1] then
                return table.unpack(vs)
            end
        end
        return false
    elseif awt.tag == '_and_' then
        for i, x in ipairs(awt) do
            local vs = { check_ret(x, ...) }
            if vs[1] then
                local t = (#vs>2 and {table.unpack(vs,2)}) or vs[2]
                awt[i] = { tag='_ok_', t }
            end
        end
        local ret = {}
        for _,x in ipairs(awt) do
            if x.tag == '_ok_' then
                ret[#ret+1] = x[1]
            else
                return false
            end
        end
        return true, table.unpack(ret)
    elseif mta and mta.__atmos then
        return mta.__atmos(awt, ...)
    elseif mte and mte.__atmos then
        return mte.__atmos(awt, ...)
    elseif awt.tag == 'boolean' then
        if e == false then
            -- never awakes
            return false
        elseif e == true then
            return true, ...
        else
            error "bug found : impossible case"
        end
    elseif awt.tag == '_==_' then
        for i,v in ipairs(awt) do
            if not _is_(select(i,...),v) then
                return false
            end
        end
        if getmetatable(e) == meta_task then
            return true, e.ret --, e
        elseif getmetatable(e) == meta_tasks then
            -- invert ts,t -> t,ts
            return true, select(2,...), select(1,...), select(3,...)
        else
            return true, ...
        end
    elseif awt.tag == 'function' then
        local es = { ... }
        return (function (v, ...)
            if select('#',...) == 0 then
                return v, table.unpack(es)
            else
                return v, ...
            end
        end)(e(...))
    else
        return false
    end
end

local function awake (err, ...)
    local me = assert(run.me(true))
    if err then
        error((...), 0)
    else
        local awt = me._.await
        return (function (ok, ...)
            if ok then
                return ...
            else
                return awake(coroutine.yield())
            end
        end)(check_ret(awt, ...))
    end
end

local function clock_to_ms (clk)
    return (clk.ms                         or 0) +
           (clk.s   and clk.s  *1000       or 0) +
           (clk.min and clk.min*1000*60    or 0) +
           (clk.h   and clk.h  *1000*60*60 or 0)
end

local meta_clock; meta_clock = {
    -- await(clock{ms=100})
    -- vs
    -- emit('clock',100)
    -- emit(clock{ms=100})
    __atmos = function (a, e, dt, now)
        local ma = getmetatable(a)
        local me = getmetatable(e)
        if (ma == meta_clock) and (e=='clock' or me==meta_clock) then
            if e == 'clock' then
                a.cur = a.cur - dt
                return (a.cur <= 0), 'clock', -a.cur, now
            else
                a.cur = a.cur - clock_to_ms(e)
                return (a.cur <= 0), 'clock', -a.cur, nil
            end
        else
            return false
        end
    end
}

local function await_to_table (e, ...)
    local T
    if type(e) == 'table' then
        if (getmetatable(e) == meta_task) or getmetatable(e) == meta_tasks then
            T = { tag='_==_', e,... }
        elseif S.is(e) then
            --error'TODO'
            T = { tag='_==_', spawn(function() return e() end),... }
        elseif e.tag=='_or_' or e.tag=='_and_' then
            T = e
            for i,v in ipairs(T) do
                T[i] = await_to_table(table.unpack(v))
            end
        else
            if e.tag == 'clock' then
                e.cur = clock_to_ms(e)
                T = e
            else
                T = { tag='_==_', e,... }
            end
        end
    elseif type(e) == 'function' then
        T = { tag='function', e,... }
    elseif type(e) == 'boolean' then
        T = { tag='boolean', e,... }
    else
        T = { tag='_==_', e,... }
    end
    T.time = TIME
    return T
end

function run.await (e, ...)
    -- await(stream)
    -- await { tag='clock' }
    -- await(f)     -- f(...)
    -- await(true/false)
    -- await(task)
    -- await(...)
    -- await(a _and_ b)

    local t = run.me(true)
    assertn(2, t, "invalid await : expected enclosing task", 2)
    assertn(2, e~=nil, "invalid await : expected event", 2)

    t._.await = await_to_table(e, ...)

    local chk,ret = check_task_ret(t._.await)
    if chk then
        return ret
    end

    return awake(coroutine.yield())
end

function run.clock (t)
    assertn(2, type(t)=='table', "invalid clock : expected table")
    t.tag = 'clock'
    return setmetatable(t, meta_clock)
end

function run._or_ (...)
    local t = {
        tag = '_or_',
        ...
    }
    for i,x in ipairs(t) do
        if type(x) == 'table' then
            if getmetatable(x)==meta_task or getmetatable(x)==meta_tasks or x.tag then
                t[i] = { x }
            end
        else
            t[i] = { x }
        end
    end
    return t
end

function run._and_ (...)
    local t = {
        tag = '_and_',
        ...
    }
    for i,x in ipairs(t) do
        if type(x) == 'table' then
            if getmetatable(x)==meta_task or getmetatable(x)==meta_tasks or x.tag then
                t[i] = { x }
            end
        else
            t[i] = { x }
        end
    end
    return t
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
        return ok, err
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

function run.emit (stk, to, e, ...)
    TIME = TIME + 1
    local time = TIME
    local ret = xcall(debug.getinfo(2), stk and "emit", emit, time, fto(run.me(false),to), e, ...)
    local me = run.me(true)
    if me and me._.status=='aborted' then
        -- TODO: lua5.5
        coroutine.yield()   -- wait to be closed from outside
    end
    return ret
end

-------------------------------------------------------------------------------

function run.toggle (t, on)
    if type(t) == 'string' then
        local e, f = t, on
        assertn(2, type(f)=='function', "invalid toggle : expected task prototype")
        do
            local t <close> = run.spawn(debug.getinfo(2), nil, true, f)
            local _ <close> = run.spawn(debug.getinfo(2), nil, true, function ()
                while true do
                    run.await(e, false)
                    run.toggle(t, false)
                    run.await(e, true)
                    run.toggle(t, true)
                end
            end)
            return run.await(t)
        end
    end

    assertn(2, getmetatable(t)==meta_task or getmetatable(t)==meta_tasks,
        "invalid toggle : expected task")
    assertn(2, type(on) == 'boolean', "invalid toggle : expected bool argument")
    if on then
        assertn(2, t._.status=='toggled', "invalid toggle : expected toggled off task")
        t._.status = nil
    else
        assertn(2, t._.status==nil --[[and coroutine.status(t._.th)=='suspended']],
            "invalid toggle : expected awaiting task")
        t._.status = 'toggled'
    end
end

-------------------------------------------------------------------------------

function run.every (...)
    assertn(2, run.me(true), "invalid every : expected enclosing task")
    local t = { ... }
    local blk = table.remove(t, #t)
    while true do
        blk(run.await(table.unpack(t)))
    end
end

local meta_par = {
    __close = function (ts)
        for _, t in ipairs(ts) do
            meta_task.__close(t)
        end
    end
}

function run.par (...)
    assertn(2, run.me(true), "invalid par : expected enclosing task")
    local fs = { ... }
    local ts <close> = setmetatable({}, meta_par)
    for i,f in ipairs(fs) do
        assertn(2, type(f) == 'function', "invalid par : expected task prototype")
        ts[i] = run.spawn(debug.getinfo(2), nil, true, select(i,...))
    end
    run.await(false)
end

function run.par_or (...)
    assertn(2, run.me(true), "invalid par_or : expected enclosing task")
    local fs = { ... }
    local ts <close> = setmetatable({}, meta_par)
    for i,f in ipairs(fs) do
        assertn(2, type(f) == 'function', "invalid par_or : expected task prototype")
        ts[i] = run.spawn(debug.getinfo(2), nil, true, f)
    end
    return run.await(run._or_(table.unpack(ts)))
end

function run.par_and (...)
    assertn(2, run.me(true), "invalid par_or : expected enclosing task")
    local fs = { ... }
    local ts <close> = setmetatable({}, meta_par)
    for i,f in ipairs(fs) do
        assertn(2, type(f) == 'function', "invalid par_or : expected task prototype")
        ts[i] = run.spawn(debug.getinfo(2), nil, true, f)
    end
    return run.await(run._and_(table.unpack(ts)))
end

function run.watching (...)
    assertn(2, run.me(true), "invalid watching : expected enclosing task")
    local t = { ... }
    local f = table.remove(t, #t)
    assertn(2, type(f) == 'function', "invalid watching : expected task prototype")
    local spw <close> = run.spawn(debug.getinfo(2), nil, true, f)
    return run.await(run._or_({table.unpack(t)}, spw))
end

return run
