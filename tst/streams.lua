local atmos = require "atmos"

local S = require "atmos.streams"
S.methods(true)

require "test"

do
    print("Testing...", "await 1")
    local s = S.fr_await('E')
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
        return await('E')
    end
    local s = S.fr_task(T)
    emit 'E'
    emit 'E'
    spawn(function()
        local t = s:take(2):to_table()
        out('ok')
        assert(#t==2 and t[1]=='E' and t[2]=='E')
    end)
    out 'antes'
    emit('E', 1)
    out 'meio'
    emit('E')
    out 'depois'
    emit('E')
    out 'fim'
    assertx(out(), "antes\ndefer\nmeio\ndefer\nok\ndepois\nfim\n")
    atmos.close()
end

do
    print("Testing...", "task 2: abortion")
    local T = function ()
        local _ <close> = defer(function()
            out'defer'
        end)
        return await('E')
    end
    local s = S.fr_task(T)
    spawn(function()
        watching('F', function()
            S.to_table(s)
            error "never reached"
        end)
    end)
    emit('E')
    emit('E')
    emit('F')
    assertx(out(), "defer\ndefer\ndefer\n")
    atmos.close()
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
