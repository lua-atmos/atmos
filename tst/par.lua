require "test"
require "atmos"

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
        par(10)
    end)
    assertfx(err, "par.lua:46: invalid spawn : expected task prototype")
end

