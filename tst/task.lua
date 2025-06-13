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
    spawn(t, 10)
    emit('X')
    assertx(out(), "10\nX\n")
end

do
    print("Testing...", "task 2")
    local function T (a)
        out(a)
        local b = await(true)
        out(b)
    end
    spawn(T,10)
    emit('ok')
    assertx(out(), "10\nok\n")
end

do
    print("Testing...", "task 3")
    function tk (v)
        local e1 = await(true)
        out(1, e1)
        local e2 = await(true)
        out(2, e2)
    end
    spawn (tk)
    emit(1)
    emit(2)
    emit(3)
    assertx(out(), "1\t1\n2\t2\n")
end

do
    print("Testing...", "emit 1")
    emit(1)
    (function ()
        emit_in(false,1)
    end)()
    assertx(out(), "anon.atm : line 1 : invalid emit : invalid target")
end
