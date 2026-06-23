local atmos = require "atmos"
require "test"

print '--- PAR ---'

do
    print("Testing...", "par 1")
    spawn(task(function ()
        par (
            function () end
        )
    end))
    out("ok")
    assertx(out(), "ok\n")
    atmos.stop()
end

do
    print("Testing...", "par 2")
    spawn(task(function ()
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
    end))
    emit 'X'
    emit 'Z'
    emit 'Z'
    emit 'X'
    assertx(out(), "X\nZ\nZ\nX\n")
    atmos.stop()
end

do
    print("Testing...", "par 3: err")
    local _,err = pcall(function ()
        spawn(task(function ()
            par(10)
        end))
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
    print("Testing...", "par_any 1")
    spawn(task(function ()
        par_any (
            function ()
                local e = await('X')
                out(e.tag, e[1])
            end,
            function ()
                local e = await('Y')
                out(e.tag, e[1])
            end
        )
        out('ok')
    end))
    emit{tag='Y',10}
    emit('X')
    assertx(out(), "Y\t10\nok\n")
    atmos.stop()
end

do
    print("Testing...", "par_any 2")
    spawn(task(function ()
        local v = par_any (
            function ()
                return await('X')
            end,
            function ()
                local e = await('Y')
                return e[1]
            end
        )
        out(v)
    end))
    emit('Z')
    emit{tag='Y', 10}
    assertx(out(), "10\n")
    atmos.stop()
end

do
    print("Testing...", "par_any 3")
    spawn(task(function ()
        local v = par_any (
            function ()
                return await('X')
            end,
            function ()
                return ('Y')
            end
        )
        out(v)
    end))
    assertx(out(), "Y\n")
    atmos.stop()
end

do
    print("Testing...", "par_any 4")
    spawn(task(function ()
        par_any (
            function ()
                await 'X'
                out 'ok'
            end,
            function ()
                await 'X'
                out 'no'
            end
        )
    end))
    emit 'X'
    assertx(out(), "ok\n")
    atmos.stop()
end

do
    print("Testing...", "par_any 5")
    spawn(task(function ()
        par_any (
            function ()
                await(true)
                out 'ok'
            end,
            function ()
                await(true)
                out 'no'
            end
        )
    end))
    emit()
    assertx(out(), "ok\n")
    atmos.stop()
end

do
    print("Testing...", "par_any 6")
    local _,err = pcall(function ()
        loop(function ()
            catch(true, function ()
                par_any (
                    function ()
                        return f()
                    end,
                    function ()
                        await(false)
                    end
                )
            end)
        end)
    end)
    assertfx(trim(err), trim [[
        ==> ERROR:
         |  par.lua:%d+ %(loop%)
         v  par.lua:%d+ %(throw%)
        ==> attempt to call a nil value %(global 'f'%)
    ]])
    atmos.stop()
end

print '--- PAR_AND ---'

do
    print("Testing...", "par_all 1")
    spawn(task(function ()
        par_all (
            function ()
                out(await('X'))
            end,
            function ()
                local e = await('Y')
                out(e.tag, e[1])
            end
        )
        out('ok')
    end))
    emit{tag='Y',10}
    emit('X')
    assertx(out(), "Y\t10\nX\nok\n")
    atmos.stop()
end

do
    print("Testing...", "par_all 2")
    spawn(task(function ()
        local x,y = par_all (
            function ()
                return await('X')
            end,
            function ()
                local e = await('Y')
                return e[1]
            end
        )
        out(x,y)
    end))
    emit('Z')
    emit{tag='Y', 10}
    emit('X')
    assertx(out(), "X\t10\n")
    atmos.stop()
end

do
    print("Testing...", "par_all 3")
    spawn(task(function ()
        local x,y = par_all (
            function ()
                return await('X')
            end,
            function ()
                return ('Y')
            end
        )
        out(x,y)
    end))
    emit 'X'
    assertx(out(), "X\tY\n")
    atmos.stop()
end

print '--- WATCHING ---'

do
    print("Testing...", "watching 1")
    spawn(task(function ()
        local v = watching (true,
            function ()
                await(false)
            end
        )
        out(v)
    end))
    emit 'X'
    assertx(out(), "X\n")
    atmos.stop()
end

do
    print("Testing...", "watching 2 (par_any)")
    spawn(task(function ()
        local v = par_any (
            function ()
                return await('X')
            end,
            function ()
                return 'Y'
            end
        )
        out(v)
    end))
    emit 'X'
    assertx(out(), "Y\n")
    atmos.stop()
end

do
    print("Testing...", "watching 2 (par_any)")
    spawn(task(function ()
        local v = par_any (
            function ()
                return await(true)
            end,
            function ()
                return 'Y'
            end
        )
        out(v)
    end))
    emit 'X'
    assertfx(out(), "Y\n")
    atmos.stop()
end

do
    print("Testing...", "watching 2")
    spawn(task(function ()
        local v = watching ('X',
            function ()
                return 'Y'
            end
        )
        out(v)
    end))
    emit 'X'
    assertx(out(), "Y\n")
    atmos.stop()
end

do
    print("Testing...", "watching 3")
    spawn(task(function ()
        local v = watching (false,
            function ()
                return await('X')
            end
        )
        out(v)
    end))
    emit 'X'
    assertx(out(), "X\n")
    atmos.stop()
end

do
    print("Testing...", "watching 4: error")
    local _,err = pcall(function ()
        watching (false, function () end)
    end)
    assertfx(err, "par.lua:%d+: invalid watching : expected enclosing task")
end

do
    print("Testing...", "watching 5: error")
    local _,err = pcall(function ()
        spawn(task(function ()
            watching (false, 'no')
        end))
    end)
    assertfx(err, "par.lua:%d+: invalid watching : expected task prototype")
end

do
    print("Testing...", "watching 6")
    spawn(task(function ()
        local v = watching ({tag='until', function (e) return e and e.tag=='X' and e[1]==10 and e[1] end},
            function ()
                await(false)
            end
        )
        out(v)
    end))
    emit{tag='X', 20}
    emit{tag='X', 10}
    assertx(out(), "10\n")
    atmos.stop()
end

do
    print("Testing...", "watching 7")
    spawn(task(function ()
        watching (true,
            function ()
                await(true)
                out 'no'
            end
        )
        out 'ok'
    end))
    emit()
    assertx(out(), "ok\n")
    atmos.stop()
end

do
    print("Testing...", "watching 8")
    spawn(task(function ()
        watching ('X',
            function ()
                await('X')
                out 'no'
            end
        )
        out 'ok'
    end))
    emit 'X'
    assertx(out(), "ok\n")
    atmos.stop()
end
