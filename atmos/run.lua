require "atmos.util"

local run = {}

local task_gc

local meta_defer = {
    __close = function (t) t.f() end
}
local meta_tasks; meta_tasks = {
    __close = function (ts)
        for _,dn in ipairs(ts._.dns) do
            getmetatable(dn).__close(dn)
        end
    end,
    next = function (s, i)
        if i == s.max then
            return nil
        else
            i = i + 1
            return i, s.ts._.dns[i]
        end
    end,
    __pairs = function (ts)
        ts._.ing = ts._.ing + 1
        local close = setmetatable({}, {
            __close = function ()
                ts._.ing = ts._.ing - 1
                task_gc(ts)
            end
        })
        return meta_tasks.next, {ts=ts,max=#ts._.dns}, 0, close
    end,
}
local meta_task = {
    __close = function (t)
        for _,dn in ipairs(t._.dns) do
            getmetatable(dn).__close(dn)
        end
        if coroutine.status(t._.co) == 'normal' then
            -- cannot close now
            -- (emit continuation will raise error)
            t._.status = 'aborted'
        else
            coroutine.close(t._.co)
        end
    end
}

local TIME = 1

local TASKS = setmetatable({
    _ = {
        up  = nil,
        dns = {},
        ing = 0,
        gc  = false,
        max = nil,
        cache = setmetatable({}, {__mode='k'}),
    }
}, meta_tasks)

-------------------------------------------------------------------------------

local function _me_ (inv, t)
    if t == TASKS then
        return nil
    elseif (getmetatable(t) == meta_tasks) or ((not inv) and t._.inv) then
        return _me_(inv, t._.up)
    else
        return t
    end
end

function run.me (inv)
    local co = coroutine.running()
    return co and TASKS._.cache[co] and _me_(inv, TASKS._.cache[co])
end

-------------------------------------------------------------------------------

local function task_resume_result (t, ok, err)
    if ok then
        -- no error: continue normally
    elseif err == 'atm_aborted' then
        -- callee aborted from outside: continue normally
        coroutine.close(t._.co)   -- needs close bc t.co is in error state
    else
        error(err, 0)
    end

    if coroutine.status(t._.co) == 'dead' then
        t._.ret = err
        t._.up._.gc = true
        --if t.status ~= 'aborted' then
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
            if getmetatable(s)==meta_task and coroutine.status(s._.co)=='dead' then
                table.remove(t._.dns, i)
            end
        end
    end
end

---------------------------------------------------------------------------------
-------------------------------------------------------------------------------

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

local function tothrow (n, ...)
    local dbg = debug.getinfo(1+n)
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
    return error(tothrow(2,...))
end

function run.catch (e, blk)
    return (function (ok, err, ...)
        if ok then
            return ok,err,...
        elseif getmetatable(err) == meta_throw then
            if e == false then
                error(err, 0)
            elseif e==true or err[1]==e then
                return false, table.unpack(err)
            else
                error(err, 0)
            end
        else
             error(err, 0)
        end
    end)(pcall(blk))
end

local function panic (err)
    local str = ""
    for i,e in ipairs(err) do
        if i > 1 then
            str = str .. ", "
        end
        str = str .. tostring(e) or ('('..type(e)..')')
    end
    io.stderr:write("==> ERROR:\n")

    for i=#err._.pos, 1, -1 do
        local t = err._.pos[i]
        io.stderr:write(" |  ")
        for j=1, #t do
            local e = t[j]
            io.stderr:write(e.dbg.file .. ":" .. e.dbg.line .. " (" .. e.msg.. ")")
            if j < #t then
                io.stderr:write(" <- ")
            end
        end
        io.stderr:write("\n")
    end

    io.stderr:write(" v  " .. err._.dbg.file .. ":" .. err._.dbg.line .. " (throw)")
    for i=1, #err._.pre do
        local e = err._.pre[i]
        io.stderr:write(" <- ")
        io.stderr:write(e.dbg.file .. ":" .. e.dbg.line .. " (" .. e.msg .. ')')
    end
    io.stderr:write("\n")

    io.stderr:write("==> " .. str .. '\n')
    os.exit()
end

local function xcall (n, stk, f, ...)
    return (function (ok, err, ...)
        if ok then
            return err, ...
        end
        if stk then
            if (getmetatable(err) ~= meta_throw) then
                err = tothrow(n+1, err)
            end
            if getmetatable(err) == meta_throw then
                local dbg = debug.getinfo(n+1)
                local t = trace()
                err._.pos[#err._.pos+1] = t
                table.insert(t, 1, {
                    msg = stk,
                    dbg = { file=dbg.short_src, line=dbg.currentline },
                })
            end
            if run.me(true) == nil then
                panic(err)
            end
        end
        error(err)
    end)(pcall(f, ...))
end

function run.call (steps, body)
    assertn(2, type(steps) == 'table', "invalid call : expected table")
    assertn(2, type(body) == 'function', "invalid call : expected function")
    return xcall(1, "call", function ()
        local t <close> = run.spawn(4, nil, false, body)
        local i = 0
        while coroutine.status(t._.co) ~= 'dead' do
            i = i % #steps
            if steps[i+1](steps) then
                break
            end
            i = i + 1
        end
        run.close()
        return t._.ret
    end)
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

function run.task (n, inv, f)
    assertn(3, type(f)=='function', "invalid task : expected function")
    local dbg = debug.getinfo(n+1)
    local t = {
        _ = {
            up  = nil,
            dns = {},
            ing = 0,
            gc  = false,
            dbg = {file=dbg.short_src, line=dbg.currentline},
            ---
            co  = coroutine.create(f),
            inv = inv,
            status = nil, -- aborted, toggled
            await = {
                time = 0,
            },
            ret = nil,
        }
    }
    TASKS._.cache[t._.co] = t
    setmetatable(t, meta_task)
    return t
end

function run.spawn (n, up, inv, t, ...)
    if type(t) == 'function' then
        t = run.task(n+1, inv, t)
        if t == nil then
            return nil
        else
            return run.spawn(n, up, inv, t, ...)
        end
    end
    assertn(3, getmetatable(t)==meta_task, "invalid spawn : expected task prototype")

    up = up or run.me(true) or TASKS
    if up._.max and #up._.dns>=up._.max then
        return nil
    end
    up._.dns[#up._.dns+1] = t
    t._.up = assert(t._.up==nil and up)

    task_resume_result(t, coroutine.resume(t._.co, ...))
    return t
end

-------------------------------------------------------------------------------

local function check_task_ret (t)
    if t.tag == '_==_' then
        if (getmetatable(t[1]) == meta_task) and (coroutine.status(t[1]._.co) == 'dead') then
            return true, t[1]._.ret, t[1]
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
    local e = awt[1]
    local mt = getmetatable(...)
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
    elseif mt and mt.__atmos then
        return mt.__atmos(awt, ...)
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
            if v ~= select(i,...) then
                return false
            end
        end
        if getmetatable(e) == meta_task then
            return true, e._.ret --, e
        elseif getmetatable(e) == meta_tasks then
            -- invert ts,t -> t,ts
            return true, select(2,...), select(1,...), select(3,...)
        else
            return true, ...
        end
    elseif awt.tag == 'function' then
        return e(...)
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
    __atmos = function (awt, evt)
        if getmetatable(awt) == meta_clock then
            awt.cur = awt.cur - clock_to_ms(evt)
            return (awt.cur <= 0), 'clock', -awt.cur
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
        elseif e.tag=='_or_' or e.tag=='_and_' then
            T = e
            for i,v in ipairs(T) do
                T[i] = await_to_table(table.unpack(v))
            end
        else
            if e.tag == 'clock' then
                e.cur = clock_to_ms(e)
            end
            T = e
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
    -- await { tag='clock' }
    -- await(f)     -- f(...)
    -- await(true/false)
    -- await(t)
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

    --local chk = (t.tag=='task') and atm_task_awake_check(t,...)

    t._.ing = t._.ing + 1
    for i=1, #t._.dns do
        local dn = t._.dns[i]
        --print(t, dn, i)
        --f(dn, ...)
        ok, err = pcall(emit, time, dn, ...)
        if not ok then
            break
        end
    end
    t._.ing = t._.ing - 1

    task_gc(t)

    if getmetatable(t) == meta_task then
        if not ok then
--print('xxx', ok, err, ...)
            if coroutine.status(t._.co) == 'suspended' then
                ok, err = coroutine.resume(t._.co, 'atm_error', err)
            end
            assertn(0, ok, err) -- TODO: error in defer?
        else
            if (t._.await.time < time) and (coroutine.status(t._.co) == 'suspended') then
                task_resume_result(t, coroutine.resume(t._.co, nil, ...))
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
    local me = run.me(false)
    local ret = xcall(2, stk and "emit", emit, time, fto(me,to), e, ...)
    assertn(0, (not me) or me._.status~='aborted', 'atm_aborted')
    return ret
end

-------------------------------------------------------------------------------

function run.toggle (t, on)
    if type(t) == 'string' then
        local e, f = t, on
        assertn(2, type(f)=='function', "invalid toggle : expected task prototype")
        do
            local t <close> = run.spawn(2, nil, true, f)
            local _ <close> = run.spawn(2, nil, true, function ()
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
        assertn(2, t._.status==nil --[[and coroutine.status(t._.co)=='suspended']],
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
    local ts <close> = setmetatable({ ... }, meta_par)
    for i,f in ipairs(ts) do
        assertn(2, type(f) == 'function', "invalid par : expected task prototype")
        ts[i] = run.spawn(2, nil, true, select(i,...))
    end
    run.await(false)
end

function run.par_or (...)
    assertn(2, run.me(true), "invalid par_or : expected enclosing task")
    local ts <close> = setmetatable({ ... }, meta_par)
    for i,f in ipairs(ts) do
        assertn(2, type(f) == 'function', "invalid par_or : expected task prototype")
        ts[i] = run.spawn(2, nil, true, f)
    end
    return run.await(run._or_(table.unpack(ts)))
end

function run.par_and (...)
    assertn(2, run.me(true), "invalid par_or : expected enclosing task")
    local ts <close> = setmetatable({ ... }, meta_par)
    for i,f in ipairs(ts) do
        assertn(2, type(f) == 'function', "invalid par_or : expected task prototype")
        ts[i] = run.spawn(2, nil, true, f)
    end
    return run.await(run._and_(table.unpack(ts)))
end

function run.watching (...)
    assertn(2, run.me(true), "invalid watching : expected enclosing task")
    local t = { ... }
    local f = table.remove(t, #t)
    assertn(2, type(f) == 'function', "invalid watching : expected task prototype")
    local spw <close> = run.spawn(2, nil, true, f)
    return run.await(run._or_({table.unpack(t)}, spw))
end

return run
