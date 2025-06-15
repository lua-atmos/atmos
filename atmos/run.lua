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
            -- cannot close now (emit continuation will raise error)
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

local function _me_ (nested, t)
    if (not nested) and t._.nested then
        return _me_(nested, t._.up)
    else
        return t
    end
end

function run.me (nested)
    if nested == nil then
        nested = true
    end
    local co = coroutine.running()
    return co and TASKS._.cache[co] and _me_(nested, TASKS._.cache[co])
end

-------------------------------------------------------------------------------

local function task_resume_result (t, ok, err)
    if ok then
        -- no error: continue normally
    elseif err == 'atm_aborted' then
        -- callee aborted from outside: continue normally
        coroutine.close(t._.co)   -- needs close b/c t.co is in error state
    else
        error(err, 0)
    end

    if coroutine.status(t._.co) == 'dead' then
        t._.ret = err
        t._.up._.gc = true
        --if t.status ~= 'aborted' then
            local up = t._.up
            while getmetatable(up) == meta_tasks do
                up = up._.up
            end
            run.emit(up, t)
        --end
    end
end

local function task_awake_check (time, t, e, v, ...)
    if coroutine.status(t._.co) ~= 'suspended' then
        -- nothing to awake
        return false
    elseif t._.await.time >= time then
        -- await after emit
        return false
    elseif t._.await.e == false then
        -- never awakes
        return false
    elseif t._.await.e == true then
        -- ok
    elseif t._.await.e == e then
        -- ok
    else
        local mt = getmetatable(e)
        if mt and mt.__atmos and mt.__atmos(e, t._.await) then
            -- ok
        else
            return false
        end
    end

    if t._.await.v == nil then
        -- ok
    elseif t._.await.v == v then
        -- ok
    elseif type(t._.await.v) == 'function' then
        -- ok: call t._.await.v(v) inside
    else
        return false
    end

    return true
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

function run.throw (...)
    return error(setmetatable({...}, meta_throw), 2)
end

function run.catch (e, f, blk)
    if blk == nil then
        f,blk = nil,f
    end
    return (function (ok, err, ...)
        if ok then
            return ok,err,...
        elseif getmetatable(err) == meta_throw then
            if e == false then
                error(err, 0)
            elseif e==true or err[1]==e then
                if (f==nil or f(table.unpack(err))) then
                    return false, table.unpack(err)
                else
                    error(err, 0)
                end
            else
                error(err, 0)
            end
        else
             error(err, 0)
        end
    end)(pcall(blk))
end

-------------------------------------------------------------------------------

function run.tasks (max)
    local n = max and tonumber(max) or nil
    assertn(2, (not max) or n, "invalid tasks limit : expected number")
    local up = me() or TASKS
    local ts = {
        _ = {
            up  = up,
            dns = {},
            ing = 0,
            gc  = false,
            max = n,
        }
    }
    up._.dns[#up._.dns+1] = ts
    setmetatable(ts, meta_tasks)
    return ts
end

function run.task (f, nested)
    local t = {
        _ = {
            up  = nil,
            dns = {},
            ing = 0,
            gc  = false,
            co  = coroutine.create(f),
            nested = nested,
            status = nil, -- aborted, toggled
            ret = nil,
        }
    }
    TASKS._.cache[t._.co] = t
    setmetatable(t, meta_task)
    return t
end

function run.spawn (up, nested, t, ...)
    if type(t) == 'function' then
        t = run.task(t, nested)
        if t == nil then
            return nil
        else
            return run.spawn(up, nested, t, ...)
        end
    end
    assertn(3, getmetatable(t)==meta_task, "invalid spawn : expected task prototype")

    up = up or me() or TASKS
    if up._.max and #up._.dns>=up._.max then
        return nil
    end
    up._.dns[#up._.dns+1] = t
    t._.up = assert(t._.up==nil and up)

    --[[
    local function res (co, ...)
        return (function (ok,...)
            if not ok then
                print(debug.traceback(co))
            end
            return ok, ...
        end)(coroutine.resume(co,...))
    end
    task_resume_result(t, res(t.co, ...))
    ]]

    task_resume_result(t, coroutine.resume(t._.co, ...))
    return t
end

-------------------------------------------------------------------------------

local function await (err, a, b, ...)
    local me = assert(me())
    if err then
        error(a, 0)
    else
        -- must call t._.await.f here (vs atm_task_awake_check) bc of atm_me
        -- a=:X, b={...}, choose b over a, me._.await.f(b)
        if type(me._.await.v)~='function' or me._.await.v(b==nil and a or b) then
            if getmetatable(a) == meta_task then
                assert(b == nil)
                return a._.ret
            elseif b ~= nil then
                return b, a, ...
            else
                return a
            end
        else
            return await(coroutine.yield())
        end
    end
end

local function clock_to_ms (clk)
    return (clk.ms                         or 0) +
           (clk.s   and clk.s  *1000       or 0) +
           (clk.min and clk.min*1000*60    or 0) +
           (clk.h   and clk.h  *1000*60*60 or 0)
end

local meta_clock; meta_clock = {
    __atmos = function (evt, awt)
        if getmetatable(awt.e) == meta_clock then
            awt.e.cur = awt.e.cur - clock_to_ms(evt)
            return awt.e.cur <= 0
        else
            return false
        end
    end
}

local meta_paror = {
    __close = function (ts)
        for _, t in ipairs(ts) do
            meta_task.__close(t)
        end
    end
}

function run.await (e, v, ...)
    local t = me()
    assertn(2, t, "invalid await : expected enclosing task", 2)
    assertn(2, e~=nil, "invalid await : expected event", 2)
    if getmetatable(e) == meta_task then
        if coroutine.status(e._.co)=='dead' then
            return e._.ret
        end
    elseif getmetatable(e) == meta_clock then
        e.cur = clock_to_ms(e)
    elseif getmetatable(e) == meta_paror then
        local ts = e
        e = true
        v = function ()
            for _,t in ipairs(ts) do
                if coroutine.status(t._.co) == 'dead' then
                    return t
                end
            end
            return false
        end
        local t = v()
        if t then
            return t._.ret
        end
    end
    t._.await = { e=e, v=v, time=TIME, ... }
    return await(coroutine.yield())
end

function run.clock (t)
    return setmetatable(t, meta_clock)
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
            --[[
            if dn.status == 'aborted' then
                assert(err=='atm_aborted' and status(t)=='dead')
                close(dn)
            end
            ]]
            break
        end
    end
    t._.ing = t._.ing - 1

    task_gc(t)

    if getmetatable(t) == meta_task then
        if not ok then
            if coroutine.status(t._.co) ~= 'dead' then
                local ok, err = coroutine.resume(t._.co, 'atm_error', err)
                assertn(0, ok, err)
            end
        else
            --if chk then
            if task_awake_check(time,t,...) then
--print('awake', t.up,t)
                task_resume_result(t, coroutine.resume(t._.co, nil, ...))
            end
        end
    else
        assert(getmetatable(t) == meta_tasks)
        assertn(0, ok, err)
    end
end

function run.emit (to, e, ...)
    TIME = TIME + 1
    local time = TIME
    local me = me(true)
    emit(time, fto(me,to), e, ...)
    assertn(0, (not me) or me._.status~='aborted', 'atm_aborted')
end

-------------------------------------------------------------------------------

function run.toggle (t, on)
    if type(t) == 'string' then
        local e, f = t, on
        assertn(2, type(f)=='function', "invalid toggle : expected task prototype")
        do
            local t <close> = run.spawn(nil, true, f)
            local _ <close> = run.spawn(nil, true, function ()
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
        assertn(2, t._.status==nil and coroutine.status(t._.co)=='suspended',
            "invalid toggle : expected awaiting task")
        t._.status = 'toggled'
    end
end

-------------------------------------------------------------------------------

function run.every (e, f, blk)
    if blk == nil then
        f,blk = nil,f
    end
    assertn(2, me(), "invalid every : expected enclosing task")
    while true do
        blk(run.await(e, f))
    end
end

function run.par (...)
    assertn(2, me(), "invalid par : expected enclosing task")
    for i=1, select('#',...) do
        local f = select(i,...)
        assertn(2, type(f) == 'function', "invalid par : expected task prototype")
        run.spawn(nil, true, select(i,...))
    end
    run.await(false)
end

function run.par_or (...)
    assertn(2, me(), "invalid par_or : expected enclosing task")
    local ts <close> = setmetatable({ ... }, meta_paror)
    for i, f in ipairs(ts) do
        assertn(2, type(f) == 'function', "invalid par_or : expected task prototype")
        ts[i] = run.spawn(nil, true, f)
    end
    return run.await(setmetatable(ts, meta_paror))
end

function run.watching (e, f, blk)
    if blk == nil then
        f,blk = nil,f
    end
    local ef = function ()
        return run.await(e, f)
    end
    return run.par_or(ef, blk)
end

return run
