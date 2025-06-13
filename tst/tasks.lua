require "test"
local atmos = require "atmos"

do
    print("Testing...", "tasks 1")
    local ts = tasks()
    out(ts)
    assertfx(out(), "table: 0x")
    atmos.close()
end

do
    print("Testing...", "tasks 2: error")
    local _,err = pcall(function ()
        local ts = tasks(true)
    end)
    assertfx(err, "tasks.lua:15: invalid tasks limit : expected number")
    atmos.close()
end

do
    print("Testing...", "tasks 3")
    local function T ()
        out "in"
    end
    local ts = tasks()
    spawn_in(ts,T)
    out "out"
    assertx(out(), "in\nout\n")
    atmos.close()
end

do
    print("Testing...", "tasks 4")
    local function T ()
        out "ok"
    end
    local ts = tasks(2)
    spawn_in(ts,T)
    spawn_in(ts,T)
    assertx(out(), "ok\nok\n")
    atmos.close()
end

do
    print("Testing...", "tasks 5: limit")
    function T (v)
        out(v)
        await(true)
    end
    local ts = tasks(1)
    local ok1 = spawn_in(ts, T, 1)
    local ok2 = spawn_in(ts, T, 2)
    out(ok1==nil, ok2==nil)
    assertx(out(), "1\nfalse\ttrue\n")
    atmos.close()
end

do
    print("Testing...", "tasks 6: limit")
    function T (v)
        out(v)
        await(true)
        out(v)
    end
    local ts = tasks(1)
    local ok1 = spawn_in(ts, T, 1)
    emit()
    local ok2 = spawn_in(ts, T, 2)
    out(ok1==nil, ok2==nil)
    assertx(out(), "1\n1\n2\nfalse\tfalse\n")
    atmos.close()
end

do
    print("Testing...", "tasks 7: pairs")
    local function T (v)
        pub().v = v
        await(true)
    end
    local ts = tasks()
    spawn_in(ts, T, 10)
    spawn_in(ts, T, 20)
    for i,t in pairs(ts) do
        out(i, pub(t).v)
    end
    assertx(out(), "1\t10\n2\t20\n")
    atmos.close()
end
