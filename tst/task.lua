local atmos = require "atmos"
require "test"

print '--- AWAIT ---'

do
    print("Testing...", "await 1: error")
    local _,err = pcall(function ()
        await()
    end)
    assertfx(err, "task.lua:9: invalid await : expected enclosing task")
    atmos.close()
end

do
    print("Testing...", "await 2: error")
    local _,err = pcall(function ()
        spawn(function ()
            await()
        end)
    end)
    assertfx(err, "task.lua:19: invalid await : expected event")
    atmos.close()
end

do
    print("Testing...", "emit 1")
    local _,err = pcall(function ()
        emit(1)
        ;(function ()
            emit_in(false,1)
        end)()
    end)
    assertfx(err, "task.lua:31: invalid emit : invalid target")
    atmos.close()
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
    atmos.close()
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
    atmos.close()
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
    atmos.close()
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
    atmos.close()
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
    atmos.close()
end

print "--- AWAIT / CLOCK ---"

do
    print("Testing...", "await 3: clock")
    spawn(function ()
        await(clock{h=1,min=1,s=1,ms=10})
        out("awake")
    end)
    emit(clock{h=10})
    out("ok")
    assertx(out(), "awake\nok\n")
    atmos.close()
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
    atmos.close()
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
    emit()
    out("ok")
    assertx(out(), "awake\nok\n")
    atmos.close()
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
    emit()
    out("ok")
    assertx(out(), "ok\n")
    atmos.close()
end

print '--- PUB ---'

do
    print("Testing...", "pub 1")
    spawn (function ()
        me().v = 10
        out(me().v)
    end)
    assertx(out(), "10\n")
    atmos.close()
end

do
    print("Testing...", "pub 2: error")
    local _,err = pcall(function ()
        me().v = 10
    end)
    --assertfx(err, "task.lua:182: pub error : expected enclosing task")
    assertfx(err, "task.lua:182: attempt to index a nil valu")
    atmos.close()
end

do
    print("Testing...", "pub 3")
    local t = spawn (function ()
        me().v = 10
    end)
    out(t.v)
    assertx(out(), "10\n")
    atmos.close()
end

do
    print("Testing...", "pub 4")
    local _,err = pcall(function ()
        out(me(10).v)
    end)
    --assertfx(err, "task.lua:201: pub error : expected task")
    assertfx(err, "task.lua:202: attempt to index a nil value")
    atmos.close()
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
    atmos.close()
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
    atmos.close()
end

do
    print("Testing...", "every 2")
    spawn(function ()
        every(true, function (v) return v>10 end,
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
    atmos.close()
end

print "--- TOGGLE ---"

do
    print("Testing...", "toggle 1")
    local _,err = pcall(function ()
        toggle(1, true)
    end)
    assertx(err, "task.lua:269: invalid toggle : expected task")
    atmos.close()
end

do
    print("Testing...", "toggle 2")
    local _,err = pcall(function ()
        local f = task(function () end)
        toggle(f)
    end)
    assertx(err, "task.lua:279: invalid toggle : expected bool argument")
    atmos.close()
end

do
    print("Testing...", "toggle 2")
    --local _,err = pcall(function ()
        function T ()
        end
        local t = spawn (T)
        toggle (t,false)
        out 'ok'
    --end)
    --assertx(err, "task.lua:291: invalid toggle : expected awaiting task")
    assertx(out(), "ok\n")
    atmos.close()
end

do
    print("Testing...", "toggle 3")
    do
        local T = function ()
            out '1'
            await(true)
            out '2'
        end
        local t = task(T)

        out 'A'
        toggle (t, false)
        emit 'X'

        out 'B'
        spawn (t)
        emit 'X'

        out 'C'
        toggle (t, true)
        emit 'X'
    end
    assertx(out(), "A\nB\n1\nC\n2\n")
    atmos.close()
end

do
    print("Testing...", "toggle 4")
    do
        function T ()
            await(true)
            out(10)
        end
        local t = spawn (T)
        toggle (t, false)
        out(1)
        emit('X')
        emit('X')
        toggle (t, true)
        out(2)
        emit('X')
    end
    assertx(out(), "1\n2\n10\n")
    atmos.close()
end

do
    print("Testing...", "toggle 5")
    do
        function T ()
            local _ <close> = defer(function ()
                out(10)
            end)
            await(true)
            out(999)
        end
        local t <close> = spawn (T)
        toggle (t, false)
        out(1)
        emit ('')
        out(2)
    end
    assertx(out(), "1\n2\n10\n")
    atmos.close()
end

do
    print("Testing...", "toggle 6")
    do
        function T ()
            spawn (function ()
                await('nil')
                out(3)
            end)
            await('nil')
            out(4)
        end
        out(1)
        local t = spawn (T)
        toggle (t,false)
        emit ('nil')
        out(2)
        toggle (t,true)
        emit ('nil')
    end
    assertx(out(), "1\n2\n3\n4\n")
    atmos.close()
end

print "--- TOGGLE BLOCK ---"

do
    print("Testing...", "toggle block 1: error")
    local _,err = pcall(function ()
        toggle ('X',false)
    end)
    assertx(err, "task.lua:393: invalid toggle : expected task prototype")
    atmos.close()
end

do
    print("Testing...", "toggle block 2")
    do
        function T (v)
            toggle('Show', function ()
                out(v)
                every('Draw', function (evt)
                    out(evt)
                end)
            end)
        end
        spawn (T,0)
        emit('Draw', 1)
        emit('Show', false)
        emit('Show', false)
        emit('Draw', 99)
        emit('Show', true)
        emit('Show', true)
        emit('Draw', 2)
    end
    assertx(out(), "0\n1\n2\n")
    atmos.close()
end

do
    print("Testing...", "toggle block 3")
    do
        spawn (function ()
            local x = toggle('Show', function ()
                return 10
            end)
            out(x)
        end)
        out('ok')
    end
    assertx(out(), "10\nok\n")
    atmos.close()
end

print "--- NESTED ---"

do
    print("Testing...", "nested 01")
    do
        function T ()
            me().pub = 10
            out(me().pub)
            spawn (true, function ()
                me().pub = 20
                out(me().pub)
            end)
            out(me().pub)
        end
        spawn (T)
    end
    assertx(out(), "10\n20\n20\n")
    atmos.close()
end
