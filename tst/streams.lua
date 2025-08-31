local atmos = require "atmos"

local S = require "atmos.streams"

require "test"

do
    print("Testing...", "await 1")
    local s = S.fr_awaits('E')
    emit 'E'
    emit 'E'
    spawn(function()
        local t = s:take(2):to_table()
        out('ok')
        assert(#t==2 and t[1]=='E' and t[2]=='E')
    end)
    out 'antes'
    emit('E', 1)
    emit('E')
    out 'depois'
    emit('E')
    out 'fim'
    assertx(out(), "antes\nok\ndepois\nfim\n")
    atmos.close()
end

do
    print("Testing...", "task 1")
    local T = function ()
        local _ <close> = defer(function()
            out'defer'
        end)
        await('E')
        return 'ok'
    end
    spawn(function()
        local v = S.fr_spawns(T):to_first()
        out(v)
    end)
    emit('E')
    assertx(out(), "defer\nok\n")
    atmos.close()
end

do
    print("Testing...", "task 2: abortion")
    local T = function ()
        local _ <close> = defer(function()
            out'defer'
        end)
        await('E')
    end
    spawn(function()
        watching('F', function()
            local s = S.fr_spawns(T)
            s:to_table()
            await(false)
        end)
    end)
    emit('F')
    assertx(out(), "defer\n")
    atmos.close()
end

do
    print("Testing...", "par 1")
    local x = S.fr_awaits('X')
    local y = S.fr_awaits('Y')
    local _ <close> = spawn(function()
        local xy = x:par(y)
        xy:to_each(function(it)
            out(it)
        end)
    end)
    emit 'X'
    emit 'Y'
    emit 'X'
    assertx(out(), "X\nY\nX\n")
    atmos.close()
end

do
    print("Testing...", "par 2")
    local xy  = S.fr_awaits('X'):take(1):concat(S.fr_awaits('Y'):take(1))
    local abc = S.fr_awaits('A'):take(1):concat(S.fr_awaits('B'):take(2)):concat(S.fr_awaits('C'):take(1))
    spawn(function()
        local s = xy:par(abc)
        s:to_each(function(it)
            out(it)
        end)
    end)

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
    atmos.close()
end

do
    print("Testing...", "par 3: defer")
    function T (x)
        local _ <close> = defer(function()
            out('defer',x)
        end)
        return await(x)
    end
    local _ <close> = spawn(function()
        watching ('X', function()
            local x = S.fr_spawns(T, 'A')
            local y = S.fr_spawns(T, 'B')
            local xy = x:par(y)
            xy:take(1):to_each(function(it)
                out(it)
            end)
        end)
        out 'X'
    end)
    emit 'B'
    emit 'X'
    emit 'A'
    assertx(out(), "defer\tB\nB\ndefer\tA\nX\n")
    atmos.close()
end

do
    print("Testing...", "paror 1")
    local x = S.fr_awaits('X'):take(1)
    local y = S.fr_awaits('Y'):take(1)
    local _ <close> = spawn(function()
        local xy = x:paror(y)
        xy:to_each(function(it)
            out(it)
        end)
        out 'fim'
    end)
    emit 'X'
    emit 'Y'
    emit 'X'
    assertx(out(), "X\nfim\n")
    atmos.close()
end

do
    print("Testing...", "paror 2: defer")
    function T (x)
        local _ <close> = defer(function()
            out('defer',x)
        end)
        return await(x)
    end
    local _ <close> = spawn(function()
        local x = S.fr_spawns(T, 'A'):take(1)
        local y = S.fr_spawns(T, 'B'):take(1)
        local xy = x:paror(y)
        watching ('X', function()
            xy:to_each(function(it)
                out(it)
            end)
        end)
        out 'X'
    end)
    emit 'B'
    --emit 'X'
    emit 'A'
    assertx(out(), "defer\tB\nB\ndefer\tA\nX\n")
    atmos.close()
end


