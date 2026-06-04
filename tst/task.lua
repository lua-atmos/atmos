local atmos = require "atmos"
require "test"

print '--- AWAIT ---'

do
    print("Testing...", "await 1: error")
    local _,err = pcall(function ()
        await(true)
    end)
    assertfx(err, "task.lua:9: invalid await : expected enclosing task")
    atmos.stop()
end

do
    print("Testing...", "await 2: error")
    local _,err = pcall(function ()
        spawn(function ()
            await()
        end)
    end)
    assertfx(err, "task.lua:19: invalid await : invalid event pattern")
    atmos.stop()

    print("Testing...", "await 2: error")
    local _,err = pcall(function ()
        spawn(function ()
            await(1,2)
        end)
    end)
    assertfx(err, "task.lua:28: invalid await : invalid event pattern")
    atmos.stop()
end

do
    print("Testing...", "emit 1")
    local _,err = pcall(function ()
        emit(1)
        ;(function ()
            emit_in(false,1)
        end)()
    end)
    assertfx(err, "task.lua:40: invalid emit : invalid target")
    atmos.stop()
end

do
    print("Testing...", "task 1: await(X)")
    local T = function (a)
        out(a)
        local b = await('X')
        out(b)
    end
    local t = task(T)
    spawn(t, 10)
    emit('X')
    assertx(out(), "10\nX\n")
    atmos.stop()
end

do
    print("Testing...", "task 2: await(true)")
    local function T (a)
        out(a)
        local b = await(true)
        out(b)
    end
    spawn(T,10)
    emit('ok')
    assertx(out(), "10\nok\n")
    atmos.stop()
end

do
    print("Testing...", "task 3")
    function tk (v)
        local e1 = await(true)
        out(1, e1)
        local e2 = await(true)
        out(2, e2)
    end
    spawn (tk)
    emit(1)
    emit(2)
    emit(3)
    assertx(out(), "1\t1\n2\t2\n")
    atmos.stop()
end

do
    print("Testing...", "await 1: true")
    spawn(function ()
        await(true)
        out("awake")
    end)
    emit(10)
    out("ok")
    assertx(out(), "awake\nok\n")
    atmos.stop()
end

do
    print("Testing...", "await 2: false")
    spawn(function ()
        await(false)
        out("awake")
    end)
    emit(10)
    out("ok")
    assertx(out(), "ok\n")
    atmos.stop()
end

print "--- EMIT / SCOPE ---"

do
    print("Testing...", "emit scope 1")
    do
        spawn(true,function ()
            await 'X'
            emit 'Y'
        end)
        spawn(true,function ()
            await 'Y'
            out 'OK'
        end)
        emit 'X'
    end
    assertx(out(), "OK\n")
    atmos.stop()
end

print "--- AWAIT / CLOCK ---"

do
    print("Testing...", "await clock 1")
    spawn(function ()
        await 'X'
        await(clock{h=1,min=1,s=1,ms=10})
        out("awake")
    end)
    emit(clock{h=10})
    emit 'X'
    emit(clock{h=10})
    out("ok")
    assertx(out(), "awake\nok\n")
    atmos.stop()
end

do
    print("Testing...", "await clock 2")
    spawn(function ()
        await(clock{h=1,min=1,s=1,ms=10})
        out("awake")
    end)
    emit { tag='clock', ms=10*60*60*1000, now=0 }
    out("ok")
    assertx(out(), "awake\nok\n")
    atmos.stop()
end

do
    print("Testing...", "await clock 3")
    spawn(function ()
        every(clock{s=1}, function ()
            out("1s elapsed")
        end)
    end)
    emit 'A'
    emit { tag='clock', ms=500, now=0 }
    emit 'B'
    emit { tag='clock', ms=500, now=0 }
    emit 'C'
    emit { tag='clock', ms=500, now=0 }
    emit 'D'
    assertx(out(), "1s elapsed\n")
    atmos.stop()
end

print "--- AWAIT / TASK ---"

do
    print("Testing...", "await 4: task")
    spawn(function ()
        local t = spawn(function ()
        end)
        await(t)
        out("awake")
    end)
    out("ok")
    assertx(out(), "awake\nok\n")
    atmos.stop()
end

do
    print("Testing...", "await 5: task")
    spawn(function ()
        local t = spawn(function ()
            await(true)
        end)
        await(t)
        out("awake")
    end)
    emit(true)
    out("ok")
    assertx(out(), "awake\nok\n")
    atmos.stop()
end

do
    print("Testing...", "await 5: task - no awake")
    spawn(function ()
        local x = spawn(function ()
            await(true)
        end)
        local y = spawn(function ()
            await(false)
        end)
        await(y)
        out("awake")
    end)
    emit(true)
    out("ok")
    assertx(out(), "ok\n")
    atmos.stop()
end

do
    print("Testing...", "await 6: task - return")
    spawn(function ()
        local x = spawn(function (v)
            return v
        end, 10)
        local y = spawn(function (v)
            await(true)
            return v
        end, 20)
        out((await(y)))
        local vv,xx = await(x)
        out(vv,xx==x)
    end)
    emit(true)
    assertx(out(), "20\n10\ttrue\n")
    atmos.stop()
end

print "--- AWAIT / _OR_ ---"

do
    print("Testing...", "await or 1")
    spawn(function ()
        local v = await({tag='or', 'X', 'Y'})
        out(v.tag,v[1])
    end)
    emit { tag='Y', 10 }
    assertx(out(), "Y\t10\n")
    atmos.stop()
end

do
    print("Testing...", "await or 2")
    spawn(function ()
        local v = await {tag='or', {tag='Y',5}, {tag='Y',10}}
        out(v.tag, v[1])
    end)
    emit{tag='Y',10}
    assertx(out(), "Y\t10\n")
    atmos.stop()
end

do
    print("Testing...", "await or 3: task")
    spawn(function ()
        local t = spawn(function ()
            await 'X'
            return 10
        end)
        local v,u = await {tag='or', t, 'X'}
        out(v,u==t)
    end)
    emit 'X'
    assertx(out(), "10\ttrue\n")
    atmos.stop()
end

do
    print("Testing...", "await or 4: tasks")
    spawn(function ()
        local ts = tasks()
        local t = spawn_in(ts, function ()
            return await 'X'
        end)
        local v,u,q = await {tag='or', ts, 'X'}
        out(v=='X',u==t,q==ts)
    end)
    emit 'X'
    assertx(out(), "true\ttrue\ttrue\n")
    atmos.stop()
end

do
    print("Testing...", "await or 5: clock")
    spawn(function ()
        local v,u = await {tag='or', 'X', clock{s=1}}
        out(v,u)
    end)
    emit{tag='clock', ms=510}
    emit{tag='clock', ms=515}
    emit 'X'
    assertx(out(), "clock\t25\n")
    atmos.stop()
end

print "--- AWAIT / _AND_ ---"

do
    print("Testing...", "await and 1")
    spawn(function ()
        local v,u = await({tag='and', 'X', 'Y'})
        out(v.tag, u.tag)
    end)
    emit{tag='Y',10}
    emit{tag='X',20}
    assertx(out(), "X\tY\n")
    atmos.stop()
end

do
    print("Testing...", "await and 2")
    spawn(function ()
        local v,u = await {tag='and', 'Y', 'Y'}
        out(v,u)
    end)
    emit('Y')
    assertx(out(), "Y\tY\n")
    atmos.stop()
end

do
    print("Testing...", "await and 3: task")
    spawn(function ()
        local t = spawn(function ()
            await 'X'
            return 10
        end)
        local v,u = await {tag='and', t, 'X'}
        out(v,u)
    end)
    emit 'X'
    assertx(out(), "10\tX\n")
    atmos.stop()
end

do
    print("Testing...", "await and 4: tasks")
    spawn(function ()
        local ts = tasks()
        local t = spawn_in(ts, function ()
            return await 'X'
        end)
        local v,u = await {tag='and', ts, 'X'}
        out(v=='X', u)
    end)
    emit 'X'
    assertx(out(), "true\tX\n")
    atmos.stop()
end

do
    print("Testing...", "await and 5: clock")
    spawn(function ()
        local v,u = await {tag='and', 'X', clock{s=1}}
        out(v, u)
    end)
    emit{tag='clock', ms=510}
    emit{tag='clock', ms=515}
    emit 'X'
    assertx(out(), "X\tclock\n")
    atmos.stop()
end

print '--- AND / OR ---'

do
    print("Testing...", "await and/or: clock")
    spawn(function ()
        local ts = tasks()
        local t = spawn_in(ts, function ()
            await(false)
        end)
        local T = spawn_in(ts, function ()
            return await('Z')
        end)
        local v,u = await {tag='and', {tag='or', 'X', clock{s=1}}, {tag='or', ts, t}}
        out(v, u=='Z')
    end)
    emit{tag='clock', ms=510}
    emit 'Z'
    emit{tag='clock', ms=515}
    assertx(out(), "clock\ttrue\n")
    atmos.stop()
end

print "--- AWAIT / _NOT_ ---"

do
    print("Testing...", "await not 1")
    spawn(function ()
        local v = await {tag='not', 'X'}
        out(v.tag, v[1])
    end)
    emit{tag='X', 99}
    emit{tag='Y', 10}
    assertx(out(), "Y\t10\n")
    atmos.stop()
end

do
    print("Testing...", "await not 2: in or")
    spawn(function ()
        local v = await {tag='or', {tag='not', 'X'}, 'Y'}
        out(v.tag, v[1])
    end)
    emit 'X'
    emit{tag='Z', 5}
    assertx(out(), "Z\t5\n")
    atmos.stop()
end

print '--- PUB ---'

do
    print("Testing...", "pub 1")
    spawn (function ()
        task().v = 10
        out(task().v)
    end)
    assertx(out(), "10\n")
    atmos.stop()
end

do
    print("Testing...", "pub 2: error")
    local _,err = pcall(function ()
        task().v = 10
    end)
    --assertfx(err, "task.lua:182: pub error : expected enclosing task")
    assertfx(err, "task.lua:%d+: attempt to index a nil valu")
    atmos.stop()
end

do
    print("Testing...", "pub 3")
    local t = spawn (function ()
        task().v = 10
    end)
    out(t.v)
    assertx(out(), "10\n")
    atmos.stop()
end

do
    print("Testing...", "pub 4")
    local _,err = pcall(function ()
        out(task(10).v)
    end)
    --assertfx(err, "task.lua:201: pub error : expected task")
    --assertfx(err, "task.lua:%d+: attempt to index a nil value")
    assertx(err, "invalid task : expected function")
    atmos.stop()
end

print '--- LOOP / EVERY ---'

do
    print("Testing...", "loop 1")
    function T ()
        while true do
            local e = await(true)
            out(e)
        end
    end
    spawn(T)
    emit(10)
    emit(20)
    out("ok")
    assertx(out(), "10\n20\nok\n")
    atmos.stop()
end

do
    print("Testing...", "loop 1: check close")
    emit(10)
    assertx(out(), "")
end

do
    print("Testing...", "every 1")
    spawn(function ()
        every(true, function (e)
            out(e)
        end)
    end)
    emit(10)
    emit(20)
    out("ok")
    assertx(out(), "10\n20\nok\n")
    atmos.stop()
end

do
    print("Testing...", "every 2")
    spawn(function ()
        every(function (v) return v and v>10, v end,
            function (e)
                out(e)
            end
        )
    end)
    emit(20)
    emit(10)
    emit(30)
    out("ok")
    assertx(out(), "20\n30\nok\n")
    atmos.stop()
end

do
    print("Testing...", "every 3: break")
    spawn(function ()
        every(true, function ()
            _break_()
        end)
        out("ok")
    end)
    emit(10)
    assertx(out(), "ok\n")
    atmos.stop()
end

do
    print("Testing...", "every 4: return passes through")
    spawn(function ()
        catch('atm-func', function ()
            every(true, function ()
                throw('atm-func')   -- compiled return()
            end)
            out("never")
        end)
        out("ok")
    end)
    emit(10)
    assertx(out(), "ok\n")
    atmos.stop()
end

print "--- NESTED ---"

do
    print("Testing...", "nested 01")
    do
        function T ()
            task().pub = 10
            out(task().pub)
            spawn (true, function ()
                task().pub = 20
                out(task().pub)
            end)
            out(task().pub)
        end
        spawn (T)
    end
    assertx(out(), "10\n20\n20\n")
    atmos.stop()
end

print "--- ABORT ---"

do
    print("Testing...", "abort 1")
    do
        loop(function ()
            spawn(function ()
                spawn(function ()
                    spawn(function ()
                        out(0)
                        await(true)
                        out(2)
                        emit_in('global', true)
                        out(4)
                    end)
                    await(true)
                    out(3)
                end)
                out(1)
                emit(true)
                out(5)
            end)
            out(6)
        end)
        out(7)
    end
    assertx(out(), "0\n1\n2\n3\n5\n6\n7\n")
    atmos.stop()
end

do
    print("Testing...", "abort 2")
    do
        spawn(true, function ()
            local _ <close> = spawn(false, function ()
                await(true)
                return emit_in("global", "true")
            end)
            return await(true)
        end)
        emit("true")
        out("ok")
    end
    assertx(out(), "ok\n")
    atmos.stop()
end

do
    print("Testing...", "abort 3")
    do
        local _ <close> = spawn(function ()
            local _ <close> = spawn(function ()
                await(true)
                local _ <close> = setmetatable({}, {__close=function ()
                    out("1")
                end})
                emit_in("global", "")
            end);
            await(true)
            out("0")
        end)
        emit("")
        out("2")
    end
    assertx(out(), "0\n1\n2\n")
    atmos.stop()
end

do
    print("Testing...", "abort 4")
    do
        spawn(true, function ()
            par_or (
                function ()
                    await(false)
                end,
                function ()
                    catch('atm-do', "X",
                        function ()
                            par_or(
                                function ()
                                    await(false)
                                end,
                                function ()
                                    await("A")
                                    throw('atm-do',"X")
                                end
                            )
                        end
                    )
                    out("1")
                end
            )
            out("2")
        end)
        emit("A")
        assertx(out(), "1\n2\n")
    end
    atmos.stop()
end

print "--- ERRORS ---"

do
    print("Testing...", "spawn 1: err")
    local _,err = pcall(function ()
        spawn()
    end)
    assertfx(err, "invalid spawn : expected task prototype")
end

do
    print("Testing...", "spawn 2: err")
    local _,err = pcall(function ()
        local t = task(function()end)
        spawn(true, t)
    end)
    --assertfx(err, "task.lua:%d+: invalid spawn : expected function prototype")
    --assertfx(err, "task.lua:%d+: invalid spawn : transparent modifier mismatch")
    assertfx(err, "invalid spawn : transparent modifier mismatch")
end
