require "test"
require "atmos"

do
    print("Testing...", "defer 1")
    do
        local _ <close> = defer(function()
            out(1)
        end)
        local _ <close> = defer(function()
            out(2)
        end)
    end
    assertx(out(), "2\n1\n")
end

do
    print("Testing...", "task pin 1")
    out(1)
    do
        out(2)
        local _ <close> = spawn (function ()
            local _ <close> = defer(function ()
                out("defer")
            end)
            await(true)
        end)
        out(3)
    end
    out(4)
    assertx(out(), "1\n2\n3\ndefer\n4\n")
end

do
    print("Testing...", "task pin 2")
    out(1)
    do
        out(2)
        local _ <close> = spawn (function ()
            local _ <close> = defer(function ()
                out("defer")
            end)
            await(true)
        end)
        out(3)
    end
    out(4)
    assertx(out(), "1\n2\n3\ndefer\n4\n")
end
