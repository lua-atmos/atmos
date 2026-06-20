local S = require "atmos.streams"
local X = require "atmos.x"
require "atmos.util"
local lanes -- lazy require in `spawn`

local M = {
    TIME = 1,
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

local meta_task = {
    __tostring = function (t) return string.format('task: %p', t) end,
}
local meta_tasks
local meta_xtask

meta_tasks = {
    __tostring = function (ts) return string.format('tasks: %p', ts) end,
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

meta_xtask = {
    __tostring = function (t) return string.format('xtask: %p', t) end,
    __close = function (t)
        for _,dn in ipairs(t._.dns) do
            getmetatable(dn).__close(dn)
        end
        if t._.toggle and t._.toggle.task then
            -- close the off-tree toggle gate
            getmetatable(t._.toggle.task).__close(t._.toggle.task)
        end
        local st = coroutine.status(t._.th)
        if st == 'suspended' then
            assert(coroutine.close(t._.th))
        elseif st ~= 'dead' then
            t._.status = 'aborted'
        end
    end
}

X._metas(meta_task, meta_xtask, meta_tasks) -- inject metatables into `X.is`

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

function M.me (tra)
    local th = coroutine.running()
    return th and TASKS._.cache[th] and _me_(tra, TASKS._.cache[th])
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
        meta_xtask.__close(t)
    end
end

task_gc = function (t)
    if t._.gc and t._.ing==0 then
        t._.gc = false
        for i=#t._.dns, 1, -1 do
            local s = t._.dns[i]
            if getmetatable(s)==meta_xtask and coroutine.status(s._.th)=='dead' then
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
            msg = (getmetatable(x)==meta_xtask and 'task') or 'tasks',
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

-- break out of an enclosing loop (loop_on): tail call preserves the
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
            local v = cnd[1]
            if false then
            elseif v == false then
                error(err, 0)
            elseif v == true then
                return false, table.unpack(err)
            elseif type(v) == 'function' then
                return (function (ok, ...)
                    if ok then
                        return false, ...
                    else
                        error(err, 0)
                    end
                end)(v(table.unpack(err)))
            else
                for i=1, #cnd do
                    if not X.is(err[i],cnd[i]) then
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
        local t <close> = M.spawn(debug.getinfo(4), nil, false, M.task(debug.getinfo(4), body), ...)
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
    M.spawn(debug.getinfo(2), nil, false, M.task(debug.getinfo(2), body), ...)
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

-- prototype: bless any function into a non-callable spawnable value
function M.task (dbg, f)
    assertn(3, type(f)=='function', "invalid task : expected function")
    return setmetatable({
        _ = {
            dbg = {file=dbg.short_src, line=dbg.currentline},
            f   = f,
        }
    }, meta_task)
end

-- instance: unstarted executing task from a prototype (or raw function,
-- the transparent-combinator path)
function M.xtask (dbg, tra, T)
    local f = (getmetatable(T)==meta_task and T._.f) or (tra and T)
    assertn(2, type(f)=='function', "invalid xtask : expected task prototype")
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
            th     = coroutine.create(f),
            tra    = tra,
            status = nil,   -- aborted, toggled
            time   = 0,     -- last await time (emit > time)
            ret    = nil,
        }
    }
    TASKS._.cache[t._.th] = t
    setmetatable(t, meta_xtask)
    return t
end

function M.abort (t)
    assertn(2, getmetatable(t)==meta_xtask or getmetatable(t)==meta_tasks, "invalid abort : expected task")
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
        -- raw function: only the transparent inline-body path
        assertn(2, tra, "invalid spawn : expected task prototype")
        t = M.xtask(dbg, tra, t)
        return M.spawn(dbg, up, tra, t, ...)
    elseif getmetatable(t) == meta_task then
        -- prototype: never transparent (transparency = no identity)
        assertn(2, not tra, "invalid spawn : transparent task prototype")
        t = M.xtask(dbg, tra, t)
        return M.spawn(dbg, up, tra, t, ...)
    end
    assertn(2, getmetatable(t)==meta_xtask, "invalid spawn : expected task prototype")
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

function M.await (time, awt, ...)
    assertn(2, awt~=nil and select('#',...)==0,
        "invalid await : invalid event pattern"
    )

    local me = M.me(true)
    assertn(2, me, "invalid await : expected enclosing task")

    -- a bare pool has metatable meta_tasks and no .tag: it would never
    -- match and hang; require :any / :all to await a pool
    assertn(2, getmetatable(awt) ~= meta_tasks,
        "invalid await : unexpected tasks pool : expected ':any' or ':all'"
    )

    local tag = ((type(awt) == 'table') and awt.tag) or awt

    if tag=='or' or tag=='and' then
        local fs = {}
        for _,sub in ipairs(awt) do
            fs[#fs+1] = function () return M.await(time, sub) end
        end
        local f = (tag=='or' and M.par_or) or M.par_and
        return f(table.unpack(fs, 1, #awt))
    elseif tag == 'not' then
        assertn(2, #awt==1, "invalid await : too many arguments")
        -- pass `time` into each re-await: an internal reject keeps the
        -- original birth time, so it does not shadow an in-flight outer emit
        while true do
            local ret = table.pack(M.par_or(function()
                M.await(time, awt[1])
                return false
            end, function()
                return true, M.await(time, true)
            end))
            if ret[1] then
                return table.unpack(ret, 2, ret.n)
            end
        end
    elseif tag=='until' or tag=='while' then
        assertn(2, #awt >= 2, "invalid await : expected predicate")
        -- pass `time` into each re-await: keeps the original birth time, so
        -- an internal reject does not shadow an in-flight outer emit.
        -- until: accept when all predicates hold (last one decides result);
        -- while: accept when any predicate fails (returns the event).
        while true do
            local it = M.await(time, awt[1])
            local res, all = it, true
            for i=2, #awt do
                local r = awt[i](it)
                if not r then
                    all = false
                    break
                end
                if r ~= true then
                    res = r
                end
            end
            if tag=='until' and all then
                return res
            elseif tag=='while' and (not all) then
                return it
            end
        end
    elseif S.is(awt) then
        return M.await(time, M.spawn(debug.getinfo(2), nil, false, M.task(debug.getinfo(2), function () return awt() end)))
    end

    local mta = getmetatable(awt)
    local emt = nil

    local clk
    if type(awt) == 'number' then
        clk = awt
    end

    -- stamp await birth time: a task reacts only to broadcasts that begin
    -- after its current await is established (one wake per emit)
    me._.time = time

    while true do
        if mta and mta.__atmos then
            local ret = mta.__atmos(awt, emt)
            if ret then
                return (ret~=true and ret) or emt
            end
        elseif tag == 'tasks' then
            local ts = awt.tasks
            if awt.mode == 'all' then
                if #ts == 0 then              -- only when empty
                    return ts
                end
            elseif awt.mode == 'any' then
                if #ts == 0 then              -- immediate if empty
                    return nil, nil, ts
                elseif ts.ret then            -- some task terminated
                    return ts.ret.ret, ts.ret, ts
                end
            else
                assertn(2, false, "invalid await : invalid mode")
            end
        elseif mta == meta_xtask then
            if coroutine.status(awt._.th) == 'dead' then
                return awt.ret, awt
            end
        elseif clk then
            if clk <= 0 then
                return -clk
            end
        elseif type(awt) == 'function' then
            local ret = awt(emt)
            if ret then
                return (ret~=true and ret) or emt
            end
        end

        local err
        err, emt = coroutine.yield()
        if err then
            error(emt, 0)
        end

        local mte = getmetatable(emt)
        if mte and mte.__atmos then
            local ret = mte.__atmos(emt, awt)
            if ret then
                return (ret~=true and ret) or emt
            end
        elseif awt == true then
            return emt
        elseif awt == false then
            -- never awakes
        elseif clk or tag=='clock' then
            if type(emt) == 'number' then
                if clk then
                    -- elapsed time: a bare number advances the countdown
                    clk = clk - emt
                else
                    -- clock tick: wake on any bare-number emit, return the delta
                    return emt
                end
            end
        elseif type(awt)=='table' then
            if mta~=meta_xtask and X.gte(awt, emt) then
                return emt
            end
        else
            -- string, number
            if X.is(emt,tag) then
                return emt
            end
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
    elseif getmetatable(to)==meta_xtask or getmetatable(to)==meta_tasks then
        to = to
    else
        error("invalid emit : invalid target", 3)
    end

    return to
end

local function emit (time, t, emt, ...)
    local ok, err = true, nil

    if t._.status == 'toggled' then
        -- toggled off: drive the off-tree gate task first, then gate the subtree
        if t._.toggle then
            emit(time, t._.toggle.task, emt)
        end
        if not (t._.toggle and t._.toggle.pass==time) then
            return ok, err
        end
    end

    t._.ing = t._.ing + 1
    for i=1, #t._.dns do
        local dn = t._.dns[i]
        ok, err = pcall(emit, time, dn, emt)
        if not ok then
            break
        end
    end
    t._.ing = t._.ing - 1

    task_gc(t)

    if getmetatable(t) == meta_xtask then
        if not ok then
            if coroutine.status(t._.th) == 'suspended' then
                ok, err = coroutine.resume(t._.th, 'atm_error', err)
                if ok then
                    task_result(t, ok, err)
                end
            end
            assertn(0, ok, err) -- TODO: error in defer?
        else
            if (t._.time < time) and (coroutine.status(t._.th) == 'suspended') then
                task_result(t, coroutine.resume(t._.th, nil, emt))
            end
        end
    else
        assert(getmetatable(t) == meta_tasks)
        assertn(0, ok, err)
    end
end

function M.emit (stk, to, emt, ...)
    M.TIME = M.TIME + 1
    local ret = xcall(debug.getinfo(2), stk and "emit", emit, M.TIME, fto(M.me(false),to), emt)
    local me = M.me(true)
    if me and me._.status=='aborted' then
        -- TODO: lua5.5
        coroutine.yield()   -- wait to be closed from outside
        error "bug found"
    end
    return ret
end

-------------------------------------------------------------------------------

function M.toggle (t, on, filter, ...)
    if type(t) == 'string' then
        --@ derived: spawn body; loop { await; toggle; await; toggle }
        local e = t
        local f = filter or on               -- body is the last arg
        local p = (filter ~= nil) and on or nil
        assertn(2, type(f)=='function', "invalid toggle : expected task prototype")
        do
            local t <close> = M.spawn(debug.getinfo(2), nil, true, f)
            local _ <close> = M.spawn(debug.getinfo(2), nil, true, function ()
                while true do
                    M.await(M.TIME, {tag=e, false})
                    M.toggle(t, false, p)   -- task primitive sets up the filter
                    M.await(M.TIME, {tag=e, true})
                    M.toggle(t, true)
                end
            end)
            return M.await(M.TIME, t)
        end
    end

    assertn(2, getmetatable(t)==meta_xtask or getmetatable(t)==meta_tasks,
        "invalid toggle : expected task")
    assertn(2, type(on) == 'boolean', "invalid toggle : expected bool argument")
    if on then
        assertn(2, filter==nil, "invalid toggle : unexpected argument")
        assertn(2, t._.status=='toggled', "invalid toggle : expected toggled off task")
        t._.status = nil
        if t._.toggle then
            meta_xtask.__close(t._.toggle.task)   -- off-tree: just close it
            t._.toggle = nil
        end
    else
        assertn(2, t._.status==nil --[[and coroutine.status(t._.th)=='suspended']],
            "invalid toggle : expected awaiting task")
        t._.status = 'toggled'
        if filter ~= nil then
            -- hidden gate task (off-tree): emit drives it explicitly before the
            -- gate check; on a match it stamps t._.toggle.pass = M.TIME
            local gate = M.xtask(debug.getinfo(2), true, function ()
                while true do
                    M.await(M.TIME, filter)
                    t._.toggle.pass = M.TIME
                end
            end)
            gate._.up = t._.up
            t._.toggle = { task = gate }
            task_result(gate, coroutine.resume(gate._.th))   -- start (run to first await)
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
            M.await(M.TIME, true)
        end
    end
end

-------------------------------------------------------------------------------

--@ derived: loop { f(await(awt, payload...)) }
function M.loop_on (...)
    assertn(2, M.me(true), "invalid loop_on : expected enclosing task")
    local t = { ... }
    local blk = table.remove(t, #t)
    -- tag-specific catch: break exits the loop, but return (atm-func),
    -- abort, and any other throw still propagate past loop_on
    M.catch('atm-loop', function ()
        while true do
            blk(M.await(M.TIME, t[1], table.unpack(t, 2, #t)))
        end
    end)
end

local meta_par = {
    __close = function (ts)
        for _, t in ipairs(ts) do
            meta_xtask.__close(t)
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
    M.await(M.TIME, false)
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
        M.await(M.TIME, false)
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
        rets[i] = M.await(M.TIME, t)
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
        function () return M.await(M.TIME, t[1], table.unpack(t, 2, #t)) end,
        f
    )
end

return M
