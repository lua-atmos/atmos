require "test"
require "atmos"

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
end

do
    print("Testing...", "par 3: err")
    local _,err = pcall(function ()
        spawn (function ()
            par(10)
        end)
    end)
    assertfx(err, "par.lua:49: invalid par : expected task prototype")
end

do
    print("Testing...", "par 4: err")
    local _,err = pcall(function ()
        par(function() end)
    end)
    assertfx(err, "par.lua:58: invalid par : expected enclosing task")
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
        print(v)
    end)
    emit 'X'
    assertx(out(), "X\n")
end

do
    print("Testing...", "watching 2")
    spawn (function ()
        local v = watching (true,
            function ()
                return 'Y'
            end
        )
        print(v)
    end)
    emit 'X'
    assertx(out(), "Y\n")
end

do
    print("Testing...", "watching 3")
    spawn (function ()
        local v = watching (false,
            function ()
                return await('X')
            end
        )
        print(v)
    end)
    emit 'X'
    assertx(out(), "X\n")
end
