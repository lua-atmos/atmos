local atmos = require "atmos"

local S = require "atmos.streams"

require "test"

do
    print("Testing...", "await 1")
    local s = S.on('E')
    emit 'E'
    emit 'E'
    spawn(task(function()
        local t = s:take(2):table():to()
        out('ok')
        assert(#t==2 and t[1]=='E' and t[2]=='E')
    end))
    out 'antes'
    emit('E')
    emit('E')
    out 'depois'
    emit('E')
    out 'fim'
    assertx(out(), "antes\nok\ndepois\nfim\n")
    atmos.stop()
end

do
    print("Testing...", "emitter 1")
    spawn(task(function()
        while true do
            local e = await('x')
            out(e[1])
        end
    end))
    spawn(task(function()
        S.from(1,3):emitter('global','x'):to()
    end))
    assertx(out(), "1\n2\n3\n")
    atmos.stop()
end

do
    print("Testing...", "task 1")
    local function T ()
        await('E')
    end
    spawn(task(function()
        S.on(T):tap(out):take(2):to()
    end))
    emit('E')
    emit('E')
    emit('E')
    assertx(out(), "false\nfalse\n")
    atmos.stop()

    print("Testing...", "task 2")
    local T = function ()
        local _ <close> = defer(function()
            out'defer'
        end)
        await('E')
        return 'ok'
    end
    spawn(task(function()
        local v = S.on(T):to_first()
        out(v)
    end))
    emit('E')
    assertx(out(), "defer\nok\n")
    atmos.stop()
end

do
    print("Testing...", "task 2: abortion")
    local T = function ()
        local _ <close> = defer(function()
            out'defer'
        end)
        await('E')
    end
    spawn(task(function()
        watching('F', function()
            local s = S.on(T)
            s:table():to()
            await(false)
        end)
    end))
    emit('F')
    assertx(out(), "defer\n")
    atmos.stop()
end

do
    print("Testing...", "par 1")
    local x = S.on('X')
    local y = S.on('Y')
    local _ <close> = spawn(task(function()
        local xy = S.par(x,y)
        xy:tap(out):to()
    end))
    emit 'X'
    emit 'Y'
    emit 'X'
    assertx(out(), "X\nY\nX\n")
    atmos.stop()

    print("Testing...", "xpar 1")
    local x = S.on('X')
    local y = S.on('Y')
    local _ <close> = spawn(task(function()
        local xy = S.from{x,y}:xpar()
        xy:tap(out):to()
    end))
    emit 'X'
    emit 'Y'
    emit 'X'
    assertx(out(), "X\nY\nX\n")
    atmos.stop()
end

do
    print("Testing...", "par 2")
    local xy = S.from {
        S.on('X'):take(1),
        S.on('Y'):take(1)
    }:xseq()
    local abc = S.from {
        S.on('A'):take(1),
        S.on('B'):take(2),
        S.on('C'):take(1)
    }:xseq()
    spawn(task(function()
        local s = S.par(xy,abc):tap(out):to()
    end))

    emit 'Y'
    emit 'X'    -- X
    emit 'X'
    emit 'A'    -- A
    emit 'B'    -- B
    emit 'A'
    emit 'X'
    emit 'Y'    -- Y
    emit 'C'
    emit 'Y'
    emit 'A'
    emit 'X'
    emit 'B'    -- B
    emit 'X'
    emit 'C'    -- C
    assertx(out(), "X\nA\nB\nY\nB\nC\n")
    atmos.stop()
end

do
    print("Testing...", "xpar 2")
    local xy = S.from {
        S.on('X'):take(1),
        S.on('Y'):take(1)
    }:xseq()
    local abc = S.from {
        S.on('A'):take(1),
        S.on('B'):take(2),
        S.on('C'):take(1)
    }:xseq()
    spawn(task(function()
        local s = S.from{xy,abc}:xpar():tap(out):to()
    end))

    emit 'Y'
    emit 'X'    -- X
    emit 'X'
    emit 'A'    -- A
    emit 'B'    -- B
    emit 'A'
    emit 'X'
    emit 'Y'    -- Y
    emit 'C'
    emit 'Y'
    emit 'A'
    emit 'X'
    emit 'B'    -- B
    emit 'X'
    emit 'C'    -- C
    assertx(out(), "X\nA\nB\nY\nB\nC\n")
    atmos.stop()
end

do
    print("Testing...", "par 3: defer")
    function T (x)
        local _ <close> = defer(function()
            out('defer',x)
        end)
        return await(x)
    end
    local _ <close> = spawn(task(function()
        watching ('X', function()
            local x = S.on(T, 'A')
            local y = S.on(T, 'B')
            local xy = S.par(x,y):par()
            xy:take(1):tap(out):to()
        end)
        out 'X'
    end))
    emit 'B'
    emit 'X'
    emit 'A'
    assertx(out(), "defer\tB\nB\ndefer\tA\nX\n")
    atmos.stop()
end

do
    print("Testing...", "xpar 3: defer")
    function T (x)
        local _ <close> = defer(function()
            out('defer',x)
        end)
        return await(x)
    end
    local _ <close> = spawn(task(function()
        watching ('X', function()
            local x = S.on(T, 'A')
            local y = S.on(T, 'B')
            local xy = S.from{x,y}:xpar()
            xy:take(1):tap(out):to()
        end)
        out 'X'
    end))
    emit 'B'
    emit 'X'
    emit 'A'
    assertx(out(), "defer\tB\nB\ndefer\tA\nX\n")
    atmos.stop()
end

do
    print("Testing...", "parany 1")
    local x = S.on('X'):take(1)
    local y = S.on('Y'):take(1)
    local _ <close> = spawn(task(function()
        local xy = S.parany(x,y)
        xy:tap(out):to()
        out 'fim'
    end))
    emit 'X'
    emit 'Y'
    emit 'X'
    assertx(out(), "X\nfim\n")
    atmos.stop()
end

do
    print("Testing...", "xparany 1")
    local x = S.on('X'):take(1)
    local y = S.on('Y'):take(1)
    local _ <close> = spawn(task(function()
        local xy = S.from{x,y}:xparany()
        xy:tap(out):to()
        out 'fim'
    end))
    emit 'X'
    emit 'Y'
    emit 'X'
    assertx(out(), "X\nfim\n")
    atmos.stop()
end

do
    print("Testing...", "parany 2: defer")
    function T (x)
        local _ <close> = defer(function()
            out('defer',x)
        end)
        return await(x)
    end
    local _ <close> = spawn(task(function()
        local x = S.on(T, 'A'):take(1)
        local y = S.on(T, 'B'):take(1)
        local xy = S.parany(x,y)
        watching ('X', function()
            xy:tap(out):to()
        end)
        out 'X'
    end))
    emit 'B'
    --emit 'X'
    emit 'A'
    assertx(out(), "defer\tB\nB\ndefer\tA\nX\n")
    atmos.stop()
end

do
    print("Testing...", "xparany 2: defer")
    function T (x)
        local _ <close> = defer(function()
            out('defer',x)
        end)
        return await(x)
    end
    local _ <close> = spawn(task(function()
        local x = S.on(T, 'A'):take(1)
        local y = S.on(T, 'B'):take(1)
        local xy = S.from{x,y}:xparany()
        watching ('X', function()
            xy:tap(out):to()
        end)
        out 'X'
    end))
    emit 'B'
    --emit 'X'
    emit 'A'
    assertx(out(), "defer\tB\nB\ndefer\tA\nX\n")
    atmos.stop()
end

print "--- DEBOUNCE ---"

--[[
do
    print("Testing...", "debounce 1: task")
    spawn(function()
        while true do
            local x = await(spawn(S.Debounce, 'X', function() return 'Y' end))
            out(x.v)
        end
    end)
    emit { tag='X', v=1 }
    emit 'Y'
    emit { tag='X', v=2 }
    emit { tag='X', v=3 }
    emit 'Y'
    assertx(out(), "1\n3\n")
    atmos.stop()
end
]]

do
    print("Testing...", "debounce 2: stream")
    loop(function()
        spawn(task(function()
            local x = S.on 'X'
            local y = function () return S.on 'Y' end
            x:debounce(y):tap(function(it)
                out(it.v)
            end):to()
        end))
        emit { tag='X', v=1 }
        emit 'Y'
        emit { tag='X', v=2 }
        emit { tag='X', v=3 }
        emit 'Y'
    end)
    assertx(out(), "1\n3\n")
    atmos.stop()
end


print "--- BUFFER ---"

--[[
do
    print("Testing...", "buffer 1: task")
    spawn(function()
        while true do
            local x = await(spawn(S.Buffer, 'X', 'Y'))
            out(#x)
            for _,t in ipairs(x) do
                out(t.v)
            end
        end
    end)
    emit { tag='X', v=1 }
    emit 'Y'
    emit { tag='X', v=2 }
    emit { tag='X', v=3 }
    emit 'Y'
    assertx(out(), "1\n1\n2\n2\n3\n")
    atmos.stop()
end
]]

do
    print("Testing...", "buffer 2: stream")
    spawn(task(function()
        local x = S.on 'X'
        local y = S.on 'Y'
        x:buffer(y):tap(function(it)
            out(#it)
            for _,t in ipairs(it) do
                out(t.v)
            end
        end):to()
    end))
    emit { tag='X', v=1 }
    emit { tag='X', v=2 }
    emit 'Y'
    emit 'Y'
    emit { tag='X', v=3 }
    emit 'Y'
    assertx(out(), "2\n1\n2\n0\n1\n3\n")
    atmos.stop()
    --   x   x   y    y  x   y
    --         {x,x} {}     {x}
end

--[[
do
    print("Testing...", "buffer 3: task debounce")
    spawn(function()
        while true do
            local x = await (
                spawn(S.Buffer, 'X',
                    spawn(S.Debounce, 'X', function()
                        return 'Y'
                    end)
                )
            )
            out(#x)
            for _,t in ipairs(x) do
                out(t.v)
            end
        end
    end)
    emit { tag='X', v=1 }
    emit { tag='X', v=2 }
    emit 'Y'
    emit 'Y'
    emit { tag='X', v=3 }
    emit 'Y'
    assertx(out(), "2\n1\n2\n1\n3\n")
    atmos.stop()
    --   x   x   y    y  x   y
    --         {x,x}        {x}
end
]]

do
    print("Testing...", "buffer 3: stream debounce")
    spawn(task(function()
        local x = S.on 'X'
        local y = S.on 'Y'
        local xy = x:debounce(function() return S.on'Y' end)
        x:buffer(xy):tap(function(it)
            out(#it)
            for _,t in ipairs(it) do
                out(t.v)
            end
        end):to()
    end))
    emit { tag='X', v=1 }
    emit { tag='X', v=2 }
    emit 'Y'
    emit 'Y'
    emit { tag='X', v=3 }
    emit 'Y'
    assertx(out(), "2\n1\n2\n1\n3\n")
    atmos.stop()
    --   x   x   y    y  x   y
    --         {x,x}        {x}
end

do
    print("Testing...", "buffer 4: stream debounce - bug")

    local xy = 0
    local c  = 0
    spawn(task(function()
        local clicks = S.on('X')
        clicks
            :debounce(function ()
                local ij = S.from {
                    S.on('I'):take(1),
                    S.on('J'):take(1)
                }
                return ij:xseq():skip(1)
            end)
            :tap(function () xy = xy + 1 end)
            :debounce(function () return S.on 'C' end)
            :tap(function () c = c + 1 end)
            :to()
    end))

    emit 'X'
    emit 'I'
    emit 'J'
    emit 'X'
    emit 'I'
    emit 'C'
    emit 'J'
    emit 'C'
    emit 'C'
    assert(xy == 2)
    assert(c == 2)
end

do
    print("Testing...", "buffer 5: stream debounce - bug")

    local N = 0
    spawn(task(function()
        local clicks = S.on('click')
        clicks
            :buffer(clicks:debounce(function () return S.on '250' end))
            :map(function (t) return #t end)
            :tap(function (n) N=n end)
            :debounce(function () return S.on '1000' end)
            :tap(function () N=0 end)
            :to()
    end))

    assert(N == 0)
    emit 'click'
    emit 'click'
    emit '250'
    assert(N == 2)
    emit '250'

    emit 'click'
    emit '1000'
    assert(N == 0)
    emit '250'
    assert(N == 1)
end
