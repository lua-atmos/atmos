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
    local _,err = pcall(function ()
        emit(1)
        ;(function ()
            emit_in(false,1)
        end)()
    end)
    assertfx(err, "task.lua:49: invalid emit : invalid target")
end

do
    print("Testing...", "pub 1")
    spawn (function ()
        pub().v = 10
        out(pub().v)
    end)
    assertx(out(), "10\n")
end

do
    print("Testing...", "pub 2: error")
    local _,err = pcall(function ()
        pub().v = 10
    end)
    assertfx(err, "task.lua:67: pub error : expected enclosing task")
end

do
    print("Testing...", "pub 3")
    local t = spawn (function ()
        pub().v = 10
    end)
    out(pub(t).v)
    assertx(out(), "10\n")
end


do
    print("Testing...", "pub 4")
    local _,err = pcall(function ()
        out(pub(10).v)
    end)
    assertfx(err, "task.lua:85: pub error : expected task")
end
