require "test"
require "atmos"

do
    print("Testing...", "task 1")
    local T = function (a)
        out(a)
        local b = await('X')
        out(b)
    end
    local t = task(T)
    spawn(t,10)
    emit('X')
end
assertx(out(), "10\nX\n")
