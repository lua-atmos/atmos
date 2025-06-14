local atmos = require "atmos"
require "test"

print '--- PAR ---'

do
    print("Testing...", "par 1")
    spawn (function ()
        par (
            function () end
        )
    end)
    out("ok")
    assertx(out(), "ok\n")
    atmos.close()
end

do
    print("Testing...", "par 2")
    spawn (function ()
        par (
            function ()
                while true do
                    out(await('X'))
                end
            end,
            function ()
                while true do
                    out(await('Y'))
                end
            end,
            function ()
                while true do
                    out(await('Z'))
                end
            end
        )
    end)
    emit 'X'
    emit 'Z'
    emit 'Z'
    emit 'X'
    assertx(out(), "X\nZ\nZ\nX\n")
    atmos.close()
end

do
    print("Testing...", "par 3: err")
    local _,err = pcall(function ()
        spawn (function ()
            par(10)
        end)
    end)
    assertfx(err, "par.lua:51: invalid par : expected task prototype")
end

do
    print("Testing...", "par 4: err")
    local _,err = pcall(function ()
        par(function() end)
    end)
    assertfx(err, "par.lua:60: invalid par : expected enclosing task")
end

print '--- PAR_OR ---'

do
    print("Testing...", "par_or 1")
    spawn(function ()
        par_or (
            function ()
                out(await('X'))
            end,
            function ()
                out(await('Y'))
            end
        )
        out('ok')
    end)
    emit('Y')
    emit('X')
    assertx(out(), "Y\nok\n")
    atmos.close()
end

do
    print("Testing...", "par_or 2")
    spawn(function ()
        local v = par_or (
            function ()
                return await('X')
            end,
            function ()
                return await('Y')
            end
        )
        out(v)
    end)
    emit('Z')
    emit('Y', 10)
    assertx(out(), "10\n")
    atmos.close()
end

print '--- WATCHING ---'

do
    print("Testing...", "watching 1")
    spawn (function ()
        local v = watching (true,
            function ()
                await(false)
            end
        )
        out(v)
    end)
    emit 'X'
    assertx(out(), "X\n")
    atmos.close()
end

do
    print("Testing...", "watching 2")
    spawn (function ()
        local v = watching (true,
            function ()
                return 'Y'
            end
        )
        out(v)
    end)
    emit 'X'
    assertx(out(), "Y\n")
    atmos.close()
end

do
    print("Testing...", "watching 3")
    spawn (function ()
        local v = watching (false,
            function ()
                return await('X')
            end
        )
        out(v)
    end)
    emit 'X'
    assertx(out(), "X\n")
    atmos.close()
end

do
    print("Testing...", "watching 4: error")
    local _,err = pcall(function ()
        watching (false, function () end)
    end)
    assertfx(err, "par.lua:155: invalid par_or : expected enclosing task")
end

do
    print("Testing...", "watching 5: error")
    local _,err = pcall(function ()
        spawn(function ()
            watching (false, 'no')
        end)
    end)
    assertfx(err, "par.lua:164: invalid par_or : expected task prototype")
end

do
    print("Testing...", "watching 6")
    spawn (function ()
        local v = watching ('X', function (v) return v==10 end,
            function ()
                await(false)
            end
        )
        out(v)
    end)
    emit('X', 20)
    emit('X', 10)
    assertx(out(), "10\n")
    atmos.close()
end
