local atmos = require "atmos"
require "test"

do
    print("Testing...", "tasks 1")
    local ts = tasks()
    out(ts)
    assertfx(out(), "tasks: 0x")
    atmos.stop()
end

do
    print("Testing...", "tasks 2: error")
    local _,err = pcall(function ()
        local ts = tasks(true)
    end)
    assertfx(err, "tasks.lua:%d+: invalid tasks limit : expected number")
    atmos.stop()
end

do
    print("Testing...", "tasks 3")
    local function T ()
        out "in"
    end
    local ts = tasks()
    spawn_in(ts, task(T))
    out "out"
    assertx(#ts, 0)
    assertx(out(), "in\nout\n")
    atmos.stop()
end

do
    print("Testing...", "tasks 4")
    local T = task(function ()
        out "ok"
    end)
    local ts = tasks(2)
    spawn_in(ts, T)
    spawn_in(ts, T)
    assertx(#ts, 0)
    assertx(out(), "ok\nok\n")
    atmos.stop()
end

do
    print("Testing...", "tasks 5: limit")
    local T = task(function (v)
        out(v)
        await(true)
    end)
    local ts = tasks(1)
    local ok1 = spawn_in(ts, T, 1)
    local ok2 = spawn_in(ts, T, 2)
    out(ok1==nil, ok2==nil)
    assertx(#ts, 1)
    assertx(out(), "1\nfalse\ttrue\n")
    atmos.stop()
end

do
    print("Testing...", "tasks 5: limit: spawn after termination")
    local n = 0
    function T ()
        await('x')
        n = n + 1
    end
    local ts = tasks(1)
    spawn(task(function()
        local ok1 = spawn_in(ts, task(T))
        await(ok1)
        local ok2 = spawn_in(ts, task(T))
        await(ok2)
    end))
    emit('x')
    emit('x')
    out(n)
    assertx(out(), "2\n")
    atmos.stop()
end

do
    print("Testing...", "tasks 6: limit")
    local T = task(function (v)
        out(v)
        await(true)
        out(v)
    end)
    local ts = tasks(1)
    local ok1 = spawn_in(ts, T, 1)
    assertx(#ts, 1)
    emit(true)
    assertx(#ts, 0)
    local ok2 = spawn_in(ts, T, 2)
    assertx(#ts, 1)
    out(ok1==nil, ok2==nil)
    assertx(out(), "1\n1\n2\nfalse\tfalse\n")
    atmos.stop()
end

do
    print("Testing...", "tasks 7: pairs")
    local function T (v)
        xtask().v = v
        await(true)
    end
    local ts = tasks()
    spawn_in(ts, task(T), 10)
    spawn_in(ts, task(T), 20)
    for i,t in pairs(ts) do
        out(i, t.v)
    end
    assertx(out(), "1\t10\n2\t20\n")
    atmos.stop()
end

do
    print("Testing...", "tasks 8: pairs gc: (now ok)")
    local T = task(function ()
        await(true)
        out 'ok'
    end)
    local ts = tasks(1)
    spawn_in(ts, T)
    for _, t in getmetatable(ts).__pairs(ts) do
        emit(true)                      -- kills t
        local ok = spawn_in(ts, T)  -- (no) failure b/c ts.ing>0
        out(ok ~= nil)
    end
    local ok = spawn_in(ts, T)      -- (no) success b/c ts.ing=0
    out(ok ~= nil)
    assertx(out(), "ok\ntrue\nfalse\n")
    atmos.stop()
end

print "--- TOGGLE ---"

do
    print("Testing...", "toggle 1")
    do
        local T = task(function (v)
            loop_on(true, function ()
                out(v)
            end)
        end)
        local ts = tasks()
        local t = spawn_in (ts, T, 1)
        local t = spawn_in (ts, T, 2)
        emit('X')
        toggle (ts, false)
        out("---")
        emit('X')
        emit('X')
        out("---")
        toggle (ts, true)
        emit('X')
    end
    assertx(out(), "1\n2\n---\n---\n1\n2\n")
    atmos.stop()
end

print("--- AWAIT / TASKS ---")

do
    print("Testing...", "await tasks 1")
    do
        local T = task(function (v)
            await('e'..v)
            return v
        end)
        local ts = tasks()
        local t1 = spawn_in (ts, T, 1)
        local t2 = spawn_in (ts, T, 2)
        local t3 = spawn_in (ts, T, 3)
        spawn(task(function ()
            local ret,t,ts2 = await {tag='tasks', mode='any', tasks=ts}
            assert(ret==2 and t==t2 and ts2==ts)
            out 't2'
        end))
        emit('e2')
    end
    assertx(out(), "t2\n")
    atmos.stop()
end

print "--- ERROR ---"

do
    print("Testing...", "error 1")
    local _, err = pcall(function ()
        function T ()
            await(spawn(task(function ()
                await('Y')
            end)))
            local function f ()
                throw 'OK'
            end
            f()
            --error "OK"
            --throw "OK"
        end
        loop(function ()
            spawn(task(function ()
                local ts = tasks()
                do_spawn(function ()
                    spawn_in(ts, task(T))
                    await(false)
                end)
                do_spawn(function ()
                    await('X')
                    emit('Y')
                end)
                await(false)
            end))
            emit('X')
        end)
    end)
    assertfx(trim(err), trim [[
        ==> ERROR:
         |  tasks.lua:%d+ %(loop%)
         |  tasks.lua:%d+ %(emit%) <%- tasks.lua:%d+ %(xtask%)
         |  tasks.lua:%d+ %(emit%) <%- tasks.lua:%d+ %(xtask%) <%- tasks.lua:%d+ %(xtask%) <%- tasks.lua:%d+ %(xtask%)
         v  tasks.lua:%d+ %(throw%) <%- tasks.lua:%d+ %(xtask%) <%- tasks.lua:%d+ %(tasks%) <%- tasks.lua:%d+ %(xtask%) <%- tasks.lua:%d+ %(xtask%)
        ==> OK
    ]])
end

do
    print "TODO: error w/o throw"
    print("Testing...", "error 2")
    local _, err = pcall(function ()
        loop(function ()
            local x = 1 + true
        end)
    end)
    assertfx(trim(err), trim [[
        ==> ERROR:
         |  tasks.lua:%d+ %(loop%)
         v  tasks.lua:%d+ %(throw%)
        ==> attempt to perform arithmetic on a boolean value
    ]])
end

-- :any (default) returns ret,t,ts of the first task to terminate
do
    print("Testing...", "pools :any default -> ret,t,ts")
    do
        local T = task(function (v)
            await('e'..v)
            return v*10
        end)
        local ts = tasks()
        local t1 = spawn_in (ts, T, 1)
        local t2 = spawn_in (ts, T, 2)
        spawn(task(function ()
            local ret,t,ts2 = await {tag='tasks', mode='any', tasks=ts}
            assert(t == t2)
            assert(ret == 20)
            assert(ts2 == ts)
            out 'any'
        end))
        emit('e2')
    end
    assertx(out(), "any\n")
    atmos.stop()
end

-- :any passed explicitly
do
    print("Testing...", "pools :any explicit")
    do
        function T (v)
            await('e'..v)
            return v
        end
        local ts = tasks()
        local t1 = spawn_in (ts, task(T), 1)
        spawn(task(function ()
            local ret,t,ts2 = await {tag='tasks', mode='any', tasks=ts}
            assert(t == t1)
            assert(ret == 1)
            assert(ts2 == ts)
            out 'ok'
        end))
        emit('e1')
    end
    assertx(out(), "ok\n")
    atmos.stop()
end

do
    print("Testing...", "pools :all -> last to terminate")
    do
        local T = task(function (v)
            await('e'..v)
            return v
        end)
        local ts = tasks()
        local t1 = spawn_in (ts, T, 1)
        local t2 = spawn_in (ts, T, 2)
        spawn(task(function ()
            local ts2 = await {tag='tasks', mode='all', tasks=ts}
            assert(ts2 == ts)
            out 'all'
        end))
        emit('e2')
        emit('e1')
    end
    assertx(out(), "all\n")
    atmos.stop()
end

do
    print("Testing...", "pools empty -> ts")
    do
        local ts = tasks()
        spawn(task(function ()
            local ts2 = await {tag='tasks', mode='all', tasks=ts}
            assert(ts2 == ts)
            out 'empty'
        end))
    end
    assertx(out(), "empty\n")
    atmos.stop()
end

-- invalid mode is rejected
do
    print("Testing...", "pools bad mode")
    local _,err = pcall(function ()
        spawn(task(function ()
            local ts = tasks()
            spawn_in(ts, task(
                function ()
                    await(true)
                end
            ))
            await {tag='tasks', mode='foo', tasks=ts}
        end))
        emit(true)
    end)
    assertfx(err, "invalid await : invalid mode")
    atmos.stop()
end
