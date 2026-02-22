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
    atmos.close()
end

do
    print("Testing...", "thread 2: error - no body function")
    local _,err = pcall(function ()
        spawn(function ()
            thread(10)
        end)
    end)
    assertfx(err, "invalid thread : expected body function")
    atmos.close()
end

do
    print("Testing...", "thread 3: error - captures external variable")
    local _,err = pcall(function ()
        local x = 10
        spawn(function ()
            thread(function ()
                return x  -- captures 'x' as upvalue
            end)
        end)
    end)
    assertfx(err, "invalid thread : function captures external variable")
    atmos.close()
end

print "--- THREAD / BASIC ---"

do
    print("Testing...", "thread 4: basic - no return")
    local v = loop(function ()
        thread(function ()
            -- empty thread body
        end)
        out("done")
    end)
    assertx(out(), "done\n")
    atmos.close()
end

do
    print("Testing...", "thread 5: basic - return value")
    loop(function ()
        local v = thread(function ()
            return 42
        end)
        out(v)
    end)
    assertx(out(), "42\n")
    atmos.close()
end

do
    print("Testing...", "thread 6: parameters - copied values")
    loop(function ()
        local data = 10
        local factor = 3
        local v = thread(data, factor, function (data, factor)
            return data * factor
        end)
        out(v)
    end)
    assertx(out(), "30\n")
    atmos.close()
end

do
    print("Testing...", "thread 7: parameters - table copy")
    loop(function ()
        local t = { 1, 2, 3 }
        local v = thread(t, function (t)
            local sum = 0
            for _, x in ipairs(t) do
                sum = sum + x
            end
            return sum
        end)
        out(v)
    end)
    assertx(out(), "6\n")
    atmos.close()
end

do
    print("Testing...", "thread 8: string operations (string lib available)")
    loop(function ()
        local v = thread("hello world", function (s)
            return string.upper(s)
        end)
        out(v)
    end)
    assertx(out(), "HELLO WORLD\n")
    atmos.close()
end

do
    print("Testing...", "thread 9: math operations (math lib available)")
    loop(function ()
        local v = thread(9, function (n)
            return math.sqrt(n)
        end)
        out(v)
    end)
    assertx(out(), "3.0\n")
    atmos.close()
end

print "--- THREAD / ERROR PROPAGATION ---"

do
    print("Testing...", "thread 10: error inside lane propagates")
    local _,err = pcall(function ()
        loop(function ()
            thread(function ()
                error("lane error")
            end)
        end)
    end)
    assertfx(tostring(err), "lane error")
    atmos.close()
end

print "--- THREAD / LIFECYCLE ---"

do
    print("Testing...", "thread 11: parent task suspends during thread")
    loop(function ()
        out("before")
        thread(function ()
            -- heavy computation simulation
            local sum = 0
            for i = 1, 1000 do
                sum = sum + i
            end
            return sum
        end)
        out("after")
    end)
    assertx(out(), "before\nafter\n")
    atmos.close()
end

do
    print("Testing...", "thread 12: sequential threads")
    loop(function ()
        local a = thread(10, function (x) return x + 1 end)
        local b = thread(20, function (x) return x + 2 end)
        out(a, b)
    end)
    assertx(out(), "11\t22\n")
    atmos.close()
end

do
    print("Testing...", "thread 13: thread inside par_or")
    loop(function ()
        local v = par_or(
            function ()
                return thread(function () return "from thread" end)
            end,
            function ()
                await(false)
            end
        )
        out(v)
    end)
    assertx(out(), "from thread\n")
    atmos.close()
end

print "--- THREAD / ISOLATION ---"

do
    print("Testing...", "thread 14: table isolation - mutation in lane does not affect parent")
    loop(function ()
        local t = { 1, 2, 3 }
        local v = thread(t, function (t)
            t[1] = 999  -- mutate the copy
            return t[1]
        end)
        out(v)      -- lane saw 999
        out(t[1])   -- parent still has 1
    end)
    assertx(out(), "999\n1\n")
    atmos.close()
end
