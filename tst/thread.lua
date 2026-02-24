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
    emit()
    assertx(out(), "done\n")
    atmos.stop()
end

do
    print("Testing...", "thread 4: basic - return value")
    spawn(function ()
        local v = thread(function ()
            return 42
        end)
        out(v)
    end)
    os.execute("sleep 0.1")
    emit()
    assertx(out(), "42\n")
    atmos.stop()
end

do
    print("Testing...", "thread 5: parameters - upvalues")
    spawn(function ()
        local data, factor = 10, 3
        local v = thread(function ()
            return data * factor
        end)
        out(v)
    end)
    os.execute("sleep 0.1")
    emit()
    assertx(out(), "30\n")
    atmos.stop()
end

do
    print("Testing...", "thread 6: parameters - table copy")
    spawn(function ()
        local t = { 1, 2, 3 }
        local v = thread(function ()
            local sum = 0
            for _, x in ipairs(t) do
                sum = sum + x
            end
            return sum
        end)
        out(v)
    end)
    os.execute("sleep 0.1")
    emit()
    assertx(out(), "6\n")
    atmos.stop()
end

do
    print("Testing...",
        "thread 7: string operations (string lib available)")
    spawn(function ()
        local s = "hello world"
        local v = thread(function ()
            return string.upper(s)
        end)
        out(v)
    end)
    os.execute("sleep 0.1")
    emit()
    assertx(out(), "HELLO WORLD\n")
    atmos.stop()
end

do
    print("Testing...",
        "thread 8: math operations (math lib available)")
    spawn(function ()
        local n = 9
        local v = thread(function ()
            return math.sqrt(n)
        end)
        out(v)
    end)
    os.execute("sleep 0.1")
    emit()
    assertx(out(), "3.0\n")
    atmos.stop()
end

print "--- THREAD / UPVALUES ---"

do
    print("Testing...", "thread 9: upvalue - pure function")
    spawn(function ()
        local function double (n)
            return n * 2
        end
        local v = thread(function ()
            return double(21)
        end)
        out(v)
    end)
    os.execute("sleep 0.1")
    emit()
    assertx(out(), "42\n")
    atmos.stop()
end

do
    print("Testing...", "thread 10: upvalue - value")
    spawn(function ()
        local multiplier = 3
        local n = 10
        local v = thread(function ()
            return n * multiplier
        end)
        out(v)
    end)
    os.execute("sleep 0.1")
    emit()
    assertx(out(), "30\n")
    atmos.stop()
end

print "--- THREAD / ERROR PROPAGATION ---"

do
    print("Testing...",
        "thread 11: error inside lane propagates")
    local _,err = pcall(function ()
        spawn(function ()
            thread(function ()
                error("lane error")
            end)
        end)
        os.execute("sleep 0.1")
        emit()
    end)
    assertfx(tostring(err[1]), "lane error")
    atmos.stop()
end

print "--- THREAD / LIFECYCLE ---"

do
    print("Testing...",
        "thread 12: parent task suspends during thread")
    spawn(function ()
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
    os.execute("sleep 0.1")
    emit()
    assertx(out(), "before\nafter\n")
    atmos.stop()
end

do
    print("Testing...", "thread 13: sequential threads")
    spawn(function ()
        local a = thread(function ()
            return 10 + 1
        end)
        local b = thread(function ()
            return 20 + 2
        end)
        out(a, b)
    end)
    os.execute("sleep 0.1")
    emit()
    os.execute("sleep 0.1")
    emit()
    assertx(out(), "11\t22\n")
    atmos.stop()
end

do
    print("Testing...", "thread 14: thread inside par_or")
    spawn(function ()
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
    os.execute("sleep 0.1")
    emit()
    assertx(out(), "from thread\n")
    atmos.stop()
end

print "--- THREAD / ISOLATION ---"

do
    print("Testing...",
        "thread 15: table isolation"
            .. " - mutation in lane does not affect parent")
    spawn(function ()
        local t = { 1, 2, 3 }
        local v = thread(function ()
            t[1] = 999
            return t[1]
        end)
        out(v)
        out(t[1])
    end)
    os.execute("sleep 0.1")
    emit()
    assertx(out(), "999\n1\n")
    atmos.stop()
end

print "--- THREAD / REUSE ---"

do
    print("Testing...",
        "thread 16: prototype reuse (same fn, multiple calls)")
    spawn(function ()
        local function square (n)
            return n * n
        end
        local a = thread(function () return square(3) end)
        local b = thread(function () return square(7) end)
        out(a, b)
    end)
    os.execute("sleep 0.1")
    emit()
    os.execute("sleep 0.1")
    emit()
    assertx(out(), "9\t49\n")
    atmos.stop()
end

do
    print("Testing...",
        "thread 17: cache hit with updated upvalue")
    spawn(function ()
        local x = 10
        local function compute (n) return n + x end

        local a = thread(function () return compute(5) end)
        out(a)

        x = 20
        local b = thread(function () return compute(5) end)
        out(b)
    end)
    os.execute("sleep 0.1")
    emit()
    os.execute("sleep 0.1")
    emit()
    assertx(out(), "15\n25\n")
    atmos.stop()
end
