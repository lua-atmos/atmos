local run = {}

local meta_tasks = {}
local meta_task = {}

local TIME = 1

local TASKS = setmetatable({
    up  = nil,
    dns = {},
    ing = 0,
    gc  = false,
    max = nil,
    cache = setmetatable({}, {__mode='k'}),
}, meta_tasks)

-------------------------------------------------------------------------------

local function _me_ (skip_fake, t)
    if skip_fake and t.fake then
        return _me_(skip_fake, t.up)
    else
        return t
    end
end

local function me (skip_fake)
    local co = coroutine.running()
    return co and TASKS.cache[co] and _me_(skip_fake, TASKS.cache[co])
end

-------------------------------------------------------------------------------

local function task_resume_result (t, ok, err)
    if ok then
        -- no error: continue normally
    elseif err == 'atm_aborted' then
        -- callee aborted from outside: continue normally
        coroutine.close(t.co)   -- needs close b/c t.co is in error state
    else
        error(err, 0)
    end

    if coroutine.status(t.co) == 'dead' then
        t.ret = err
        t.up.gc = true
        --if t.status ~= 'aborted' then
            local up = t.up
            while getmetatable(up) == meta_tasks do
                up = up.up
            end
            emit(up, 'task', t)
        --end
    end
end

local function task_awake_check (time, t, a)
    if coroutine.status(t.co) ~= 'suspended' then
        -- nothing to awake
        return false
    elseif t.await.time >= time then
        -- await after emit
        return false
    elseif t.await.e == false then
        -- never awakes
        return false
    elseif t.await.e==true or a==t.await.e then
        return true
    else
        return false
    end
end

-------------------------------------------------------------------------------

function run.task (f, fake)
    local t = {
        up  = nil,
        dns = {},
        ing = 0,
        gc  = false,
        co  = coroutine.create(f),
        fake = fake,
        status = nil, -- aborted, toggled
        pub = nil,
        ret = nil,
    }
    TASKS.cache[t.co] = t
    setmetatable(t, meta_task)
    return t
end

function run.spawn (up, t, ...)
    if type(t) == 'function' then
        t = task(t)
        if t == nil then
            return nil
        else
            return run.spawn(up, t, ...)
        end
    end
    assertn(3, getmetatable(t)==meta_task,
        'invalid spawn : expected task prototype')

    up = up or me() or TASKS
    if up.max and #up.dns>=up.max then
        return nil
    end
    up.dns[#up.dns+1] = t
    t.up = assert(t.up==nil and up)

    task_resume_result(t, coroutine.resume(t.co, ...))
    return t
end

-------------------------------------------------------------------------------

local function await (err, a, b, ...)
    local me = assert(me())
    if err then
        error(a, 0)
    else
        -- must call t.await.f here (vs atm_task_awake_check) bc of atm_me
        -- a=:X, b={...}, choose b over a, me.await.f(b)
        if me.await.f==nil or atm_call(me.await.f, b==nil and a or b) then
            b = (getmetatable(b)==meta_task and b.ret) or b
            if b then
                return b, a, ...
            else
                return a    -- avoids repetition of a/b or a/nil
            end
        else
            return await(coroutine.yield())
        end
    end
end

function run.await (e, v, ...)
    local t = me()
    assertn(2, t, 'invalid await : expected enclosing task instance', 2)
    local tsk = (getmetatable(e) == 'task')
    if tsk then
        if coroutine.status(e.co)=='dead' then
            return e.ret
        else
            v = e
            e = 'task'
        end
    elseif e == 'clock' then
        local ms = v
        v = function (x)
            ms = ms - x
            return (ms <= 0)
        end
    elseif e == 'par_or' then
        local tsks = { ... }
        e = true
        v = function ()
            for _,tsk in ipairs(tsks) do
                if coroutine.status(tsk.co) == 'dead' then
                    return tsk
                end
            end
            return false
        end
        local tsk = v()
        if tsk then
            return tsk.ret
        end
    end
    t.await = { e=e, v=v, time=TIME }
    return await(coroutine.yield())
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
            to = to.up
            assertn(3, to~=nil, 'invalid emit : invalid target')
            n = n - 1
        end
    elseif getmetatable(to)==meta_task or getmetatable(to)==meta_tasks then
        to = to
    else
        error('invalid emit : invalid target', 3)
    end

    return to
end

local function emit (time, t, ...)
    local ok, err = true, nil

    if t.state == 'toggled' then
        return ok, err
    end

    --local chk = (t.tag=='task') and atm_task_awake_check(t,...)

    t.ing = t.ing + 1
    for i=1, #t.dns do
        local dn = t.dns[i]
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
    t.ing = t.ing - 1

    --atm_task_gc(t)

    if getmetatable(t) == meta_task then
        if not ok then
            if coroutine.status(t.co) ~= 'dead' then
                local ok, err = coroutine.resume(t.co, 'atm_error', err)
                assertn(0, ok, err)
            end
        else
            --if chk then
            if task_awake_check(time,t,...) then
--print('awake', t.up,t)
                task_resume_result(t, coroutine.resume(t.co, nil, ...))
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
    assertn(0, (not me) or me.status~='aborted', 'atm_aborted')
end

return run
