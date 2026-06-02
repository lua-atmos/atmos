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

do
    print("Testing...", "filter 1: task form")
    do
        function T ()
            spawn (function ()
                every ('Draw', function () out(10) end)
            end)
            every ('Tick', function () out(20) end)
        end
        local t = spawn (T)
        toggle (t, false, 'Draw')
        emit ('Draw')   -- passes filter -> subtree draws
        emit ('Tick')   -- gated -> frozen
        toggle (t, true)
        emit ('Tick')   -- on -> resumes
    end
    assertx(out(), "10\n20\n")
    atmos.stop()
end

do
    print("Testing...", "filter 2: block form")
    do
        function T ()
            toggle('Show', function ()
                spawn (function ()
                    every('Draw', function (_,v) out(v) end)
                end)
                every('Tick', function (_,v) out(100+v) end)
            end, 'Draw')
        end
        spawn (T)
        emit('Draw', 1)     -- on -> draws
        emit('Tick', 1)     -- on -> ticks (101)
        emit('Show', false) -- toggle off, filter 'Draw'
        emit('Draw', 2)     -- passes filter while off
        emit('Tick', 2)     -- gated while off (frozen)
        emit('Show', true)  -- toggle on
        emit('Draw', 3)
        emit('Tick', 3)     -- 103
    end
    assertx(out(), "1\n101\n2\n3\n103\n")
    atmos.stop()
end

do
    print("Testing...", "filter 3: on clears filter")
    do
        function T ()
            every ('Draw', function () out(1) end)
        end
        local t = spawn (T)
        toggle (t, false, 'Draw')
        emit ('Draw')       -- passes filter
        toggle (t, true)    -- clears filter
        toggle (t, false)   -- off, no filter
        emit ('Draw')       -- gated
        toggle (t, true)
        emit ('Draw')       -- resumes
    end
    assertx(out(), "1\n1\n")
    atmos.stop()
end
