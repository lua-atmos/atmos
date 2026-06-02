local atmos = require "atmos"
require "test"

print "--- FUNCTION ---"

do
    print("Testing...", "toggle 1")
    local _,err = pcall(function ()
        toggle(1, true)
    end)
    assertfx(err, "toggle.lua:%d+: invalid toggle : expected task")
    atmos.stop()
end

do
    print("Testing...", "toggle 2")
    local _,err = pcall(function ()
        local f = task(function () end)
        toggle(f)
    end)
    assertfx(err, "toggle.lua:%d+: invalid toggle : expected bool argument")
    atmos.stop()
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
    --assertx(err, "toggle.lua:291: invalid toggle : expected awaiting task")
    assertx(out(), "ok\n")
    atmos.stop()
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
    atmos.stop()
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
    atmos.stop()
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
    atmos.stop()
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
    atmos.stop()
end

print "--- BLOCK ---"

do
    print("Testing...", "toggle block 1: error")
    local _,err = pcall(function ()
        toggle ('X',false)
    end)
    assertfx(err, "toggle.lua:%d+: invalid toggle : expected task prototype")
    atmos.stop()
end

do
    print("Testing...", "toggle block 2")
    do
        function T (v)
            toggle('Show', function ()
                out(v)
                every('Draw', function (_,v)
                    out(v)
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
    atmos.stop()
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
    atmos.stop()
end

do
    print("Testing...", "toggle block 4: error")
    do
        spawn (function ()
            local x,v = catch('err', function ()
                toggle('Show', function ()
                    await(true)
                    throw 'err'
                end)
            end)
            out(x, v)
        end)
        emit()
        out('ok')
    end
    assertx(out(), "false\terr\nok\n")
    atmos.stop()
end

print "--- FILTER ---"
