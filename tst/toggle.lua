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
        local f = xtask(task(function () end))
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
        local t = spawn_task(task(T))
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
        local t = xtask(task(T))

        out 'A'
        toggle (t, false)
        emit 'X'

        out 'B'
        spawn_task(t)
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
        local t = spawn_task(task(T))
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
        local t <close> = spawn_task(task(T))
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
            spawn_task(task(function ()
                await('nil')
                out(3)
            end))
            await('nil')
            out(4)
        end
        out(1)
        local t = spawn_task(task(T))
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
                every('Draw', function (e)
                    out(e[1])
                end)
            end)
        end
        spawn_task(task(T),0)
        emit{tag='Draw', 1}
        emit{tag='Show', false}
        emit{tag='Show', false}
        emit{tag='Draw', 99}
        emit{tag='Show', true}
        emit{tag='Show', true}
        emit{tag='Draw', 2}
    end
    assertx(out(), "0\n1\n2\n")
    atmos.stop()
end

do
    print("Testing...", "toggle block 3")
    do
        spawn_task(task(function ()
            local x = toggle('Show', function ()
                return 10
            end)
            out(x)
        end))
        out('ok')
    end
    assertx(out(), "10\nok\n")
    atmos.stop()
end

do
    print("Testing...", "toggle block 4: error")
    do
        spawn_task(task(function ()
            local x,v = catch('err', function ()
                toggle('Show', function ()
                    await(true)
                    throw 'err'
                end)
            end)
            out(x, v)
        end))
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
            spawn_task(task(function ()
                every ('Draw', function () out(10) end)
            end))
            every ('Tick', function () out(20) end)
        end
        local t = spawn_task(task(T))
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
            toggle('Show', 'Draw', function ()
                spawn_task(task(function ()
                    every('Draw', function (e) out(e[1]) end)
                end))
                every('Tick', function (e) out(100+e[1]) end)
            end)
        end
        spawn_task(task(T))
        emit{tag='Draw', 1}     -- on -> draws
        emit{tag='Tick', 1}     -- on -> ticks (101)
        emit{tag='Show', false} -- toggle off, filter 'Draw'
        emit{tag='Draw', 2}     -- passes filter while off
        emit{tag='Tick', 2}     -- gated while off (frozen)
        emit{tag='Show', true}  -- toggle on
        emit{tag='Draw', 3}
        emit{tag='Tick', 3}     -- 103
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
        local t = spawn_task(task(T))
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

do
    print("Testing...", "filter 4: block form, 'not' (ignore one event)")
    do
        function T ()
            toggle('Show', {tag='not', 'Tick'}, function ()    -- pass all but 'Tick'
                spawn_task(task(function ()
                    every('Draw', function (e) out(e[1]) end)
                end))
                every('Tick', function (e) out(100+e[1]) end)
            end)
        end
        spawn_task(task(T))
        emit{tag='Show', false} -- off: filter passes everything except 'Tick'
        emit{tag='Draw', 1}     -- passes
        emit{tag='Tick', 1}     -- the one ignored -> frozen
        emit{tag='Draw', 2}     -- passes
        emit{tag='Show', true}
        emit{tag='Tick', 9}     -- on -> 109
    end
    assertx(out(), "1\n2\n109\n")
    atmos.stop()
end
