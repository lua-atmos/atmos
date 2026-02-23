local atmos = require "atmos"
require "test"

print "--- THREAD ---"

print "--- THREAD / ERRORS ---"

do
    print("Testing...", "thread 1: error - no enclosing task")
    local _,err = pcall(function ()
        thread(function () end)
    end)
    assertfx(err, "invalid thread : expected enclosing task")
    atmos.stop()
end

do
    print("Testing...", "thread 2: error - no body function")
    local _,err = pcall(function ()
        spawn(function ()
            thread(10)
        end)
    end)
    assertfx(err, "invalid thread : expected body function")
    atmos.stop()
end

print "--- THREAD / BASIC ---"

do
    print("Testing...", "thread 3: basic - no return")
    spawn(function ()
        thread(function ()
        end)
        out("done")
    end)
    os.execute("sleep 0.1")
    emit(true)
    assertx(out(), "done\n")
    atmos.stop()
end

do
    print("Testing...", "thread 4: basic - return value")
    loop(function ()
        local v = thread(function ()
            return 42
        end)
        out(v)
    end)
    assertx(out(), "42\n")
    atmos.stop()
end

do
    print("Testing...", "thread 5: parameters - copied values")
    loop(function ()
        local v = thread(10, 3, function (data, factor)
            return data * factor
        end)
        out(v)
    end)
    assertx(out(), "30\n")
    atmos.stop()
end

do
    print("Testing...", "thread 6: parameters - table copy")
    loop(function ()
        local v = thread({ 1, 2, 3 }, function (t)
            local sum = 0
            for _, x in ipairs(t) do
                sum = sum + x
            end
            return sum
        end)
        out(v)
    end)
    assertx(out(), "6\n")
    atmos.stop()
end

do
    print("Testing...",
        "thread 7: string operations (string lib available)")
    loop(function ()
        local v = thread("hello world", function (s)
            return string.upper(s)
        end)
        out(v)
    end)
    assertx(out(), "HELLO WORLD\n")
    atmos.stop()
end

do
    print("Testing...",
        "thread 8: math operations (math lib available)")
    loop(function ()
        local v = thread(9, function (n)
            return math.sqrt(n)
        end)
        out(v)
    end)
    assertx(out(), "3.0\n")
    atmos.stop()
end

print "--- THREAD / UPVALUES ---"

do
    print("Testing...", "thread 9: upvalue - pure function")
    loop(function ()
        local function double (n)
            return n * 2
        end
        local v = thread(21, function (n)
            return double(n)
        end)
        out(v)
    end)
    assertx(out(), "42\n")
    atmos.stop()
end

do
    print("Testing...", "thread 10: upvalue - value")
    loop(function ()
        local multiplier = 3
        local v = thread(10, function (n)
            return n * multiplier
        end)
        out(v)
    end)
    assertx(out(), "30\n")
    atmos.stop()
end

print "--- THREAD / ERROR PROPAGATION ---"

do
    print("Testing...",
        "thread 11: error inside lane propagates")
    local _,err = pcall(function ()
        loop(function ()
            thread(function ()
                error("lane error")
            end)
        end)
    end)
    assertfx(tostring(err), "lane error")
    atmos.stop()
end

print "--- THREAD / LIFECYCLE ---"

do
    print("Testing...",
        "thread 12: parent task suspends during thread")
    loop(function ()
        out("before")
        thread(function ()
            local sum = 0
            for i = 1, 1000 do
                sum = sum + i
            end
            return sum
        end)
        out("after")
    end)
    assertx(out(), "before\nafter\n")
    atmos.stop()
end

do
    print("Testing...", "thread 13: sequential threads")
    loop(function ()
        local a = thread(10, function (x)
            return x + 1
        end)
        local b = thread(20, function (x)
            return x + 2
        end)
        out(a, b)
    end)
    assertx(out(), "11\t22\n")
    atmos.stop()
end

do
    print("Testing...", "thread 14: thread inside par_or")
    loop(function ()
        local v = par_or(
            function ()
                return thread(function ()
                    return "from thread"
                end)
            end,
            function ()
                await(false)
            end
        )
        out(v)
    end)
    assertx(out(), "from thread\n")
    atmos.stop()
end

print "--- THREAD / ISOLATION ---"

do
    print("Testing...",
        "thread 15: table isolation"
            .. " - mutation in lane does not affect parent")
    loop(function ()
        local t = { 1, 2, 3 }
        local v = thread(t, function (t)
            t[1] = 999
            return t[1]
        end)
        out(v)
        out(t[1])
    end)
    assertx(out(), "999\n1\n")
    atmos.stop()
end

print "--- THREAD / REUSE ---"

do
    print("Testing...",
        "thread 16: prototype reuse (same fn, multiple calls)")
    loop(function ()
        local function square (n)
            return n * n
        end
        local a = thread(3, square)
        local b = thread(7, square)
        out(a, b)
    end)
    assertx(out(), "9\t49\n")
    atmos.stop()
end

do
    print("Testing...",
        "thread 17: cache hit with updated upvalue")
    loop(function ()
        local x = 10
        local function compute (n) return n + x end

        local a = thread(5, compute)
        out(a)

        x = 20
        local b = thread(5, compute)
        out(b)
    end)
    assertx(out(), "15\n25\n")
    atmos.stop()
end
