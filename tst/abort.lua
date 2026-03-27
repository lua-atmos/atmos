local atmos = require "atmos"
require "test"

print '--- TASK ---'

do
    print("Testing...", "abort task 1: from outside")
    spawn(function ()
        local t = spawn(function ()
            await(true)
            out("no")
        end)
        abort(t)
        emit(true)
    end)
    assertx(out(), "")
    atmos.stop()
end

do
    print("Testing...", "abort task 2: defer")
    spawn(function ()
        local t = spawn(function ()
            local _ <close> = defer(function ()
                out("defer")
            end)
            await(true)
            out("no")
        end)
        abort(t)
        emit(true)
    end)
    assertx(out(), "defer\n")
    atmos.stop()
end

do
    print("Testing...", "abort task 3: self-abort")
    spawn(function ()
        local t = task()
        out("before")
        local _ <close> = defer(function ()
            out("defer")
        end)
        abort(t)
        out("no")
    end)
    assertx(out(), "before\ndefer\n")
    atmos.stop()
end

do
    print("Testing...", "abort task 4: invalid argument")
    local _,err = pcall(function ()
        abort(1)
    end)
    assertfx(err, "abort.lua:%d+: invalid abort : expected task")
    atmos.stop()
end

print '--- TASKS ---'

do
    print("Testing...", "abort tasks 1: from outside")
    spawn(function ()
        local ts = tasks()
        spawn_in(ts, function ()
            await(true)
            out("no1")
        end)
        spawn_in(ts, function ()
            await(true)
            out("no2")
        end)
        abort(ts)
        emit(true)
    end)
    assertx(out(), "")
    atmos.stop()
end

do
    print("Testing...", "abort tasks 2: defer")
    spawn(function ()
        local ts = tasks()
        spawn_in(ts, function ()
            local _ <close> = defer(function ()
                out("defer1")
            end)
            await(true)
        end)
        spawn_in(ts, function ()
            local _ <close> = defer(function ()
                out("defer2")
            end)
            await(true)
        end)
        abort(ts)
    end)
    assertx(out(), "defer1\ndefer2\n")
    atmos.stop()
end

do
    print("Testing...", "abort tasks 3: invalid argument")
    local _,err = pcall(function ()
        abort({})
    end)
    assertfx(err, "abort.lua:%d+: invalid abort : expected task")
    atmos.stop()
end
