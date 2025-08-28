local atmos = require "atmos"

local S = require "atmos.streams"
S.methods(true)

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
        local v = S.fr_task(spawn(T)):to_first()
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
            local s = S.fr_task(spawn(T))
            await(false)
        end)
    end)
    emit('F')
    assertx(out(), "defer\n")
    atmos.close()
end

do
    print("Testing...", "merge 1")
    local xy  = S.fr_awaits('X'):take(1):concat(S.fr_awaits('Y'):take(1))
    local abc = S.fr_awaits('A'):take(1):concat(S.fr_awaits('B'):take(1)):concat(S.fr_awaits('C'):take(1))
    spawn(function()
        local s = xy:merge(abc)
        s:to_each(function(it)
            print(it)
        end)
    end)
    emit 'X'
error'oi'
    emit 'Y'
    emit 'Y'
    emit 'X'
    emit 'Y'
    --emit 'Y'
    --emit 'A'
    --emit 'B'
    --emit 'C'
end

error "OK"

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
