local atmos = require "atmos"
require "test"
local X = require "atmos.x"

print "--- PROTOTYPE / INSTANCE ---"

do
    print("Testing...", "task 1: prototype is :task")
    local T = task(function () end)
    out(X.is(T, 'task'))        -- prototype
    out(X.is(T, 'xtask'))       -- not an instance
    assertx(out(), "true\nfalse\n")
end

do
    print("Testing...", "xtask 1: instance is :xtask")
    local t = xtask(task(function () end))
    out(X.is(t, 'xtask'))       -- instance
    out(X.is(t, 'task'))        -- not a prototype
    assertx(out(), "true\nfalse\n")
end

do
    print("Testing...", "xtask 2: me")
    spawn(task(function ()
        out(xtask() ~= nil)     -- current executing task
    end))
    assertx(out(), "true\n")
    atmos.stop()
end

do
    print("Testing...", "spawn 1: prototype runs")
    local T = task(function () out 'ran' end)
    spawn(T)
    assertx(out(), "ran\n")
    atmos.stop()
end

print "--- TOSTRING ---"

do
    print("Testing...", "tostring 1: prototype")
    out(tostring(task(function () end)))
    assertfx(out(), "^task: 0x")
end

do
    print("Testing...", "tostring 2: instance")
    out(tostring(xtask(task(function () end))))
    assertfx(out(), "^xtask: 0x")
end

do
    print("Testing...", "tostring 3: pool")
    out(tostring(tasks()))
    assertfx(out(), "^tasks: 0x")
    atmos.stop()
end

print "--- FAILURES (new enforcement) ---"

do
    print("Testing...", "err 1: calling a prototype")
    local T = task(function () end)
    local _,err = pcall(function () T() end)
    assertfx(err, "attempt to call a table value")
end

do
    print("Testing...", "err 2: spawn raw function (old idiom, now rejected)")
    local _,err = pcall(function () spawn(function () end) end)
    assertfx(err, "invalid spawn : expected task prototype")
end

do
    print("Testing...", "err 3: transparent prototype")
    local T = task(function () end)
    local _,err = pcall(function () spawn(true, T) end)
    assertfx(err, "invalid spawn : transparent task prototype")
end

do
    print("Testing...", "err 4: re-wrapping a prototype")
    local T = task(function () end)
    local _,err = pcall(function () task(T) end)
    assertfx(err, "invalid task : expected function")
end
