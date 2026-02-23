local atmos = require "atmos"
require "test"

print "--- XTASK / XSPAWN ---"

print "--- XSPAWN / ERRORS ---"

do
    print("Testing...", "xspawn 1: error - no enclosing task")
    local _,err = pcall(function ()
        xspawn(function () end)
    end)
    assertfx(err, "invalid xspawn : expected enclosing task")
    atmos.stop()
end

do
    print("Testing...", "xspawn 2: error - no body function")
    local _,err = pcall(function ()
        spawn(function ()
            xspawn(10)
        end)
    end)
    assertfx(err, "invalid xspawn : expected xtask prototype")
    atmos.stop()
end

do
    print("Testing...", "xtask 1: error - no function")
    local _,err = pcall(function ()
        xtask(10)
    end)
    assertfx(err, "invalid xtask : expected function")
    atmos.stop()
end

print "--- XSPAWN / BASIC ---"

do
    print("Testing...", "xspawn 3: basic - no return")
    spawn(function ()
        xspawn(function ()
print'inside'
        end)
        out("done")
    end)
    os.execute("sleep 0.5")
print'emit'
    emit(true)
    assertx(out(), "done\n")
    atmos.stop()
end

do
    print("Testing...", "xspawn 4: basic - return value")
    loop(function ()
        local v = xspawn(function ()
            return 42
        end)
        out(v)
    end)
    assertx(out(), "42\n")
    atmos.stop()
end

do
    print("Testing...", "xspawn 5: parameters - copied values")
    loop(function ()
        local v = xspawn(function (data, factor)
            return data * factor
        end, 10, 3)
        out(v)
    end)
    assertx(out(), "30\n")
    atmos.stop()
end

do
    print("Testing...", "xspawn 6: parameters - table copy")
    loop(function ()
        local v = xspawn(function (t)
            local sum = 0
            for _, x in ipairs(t) do
                sum = sum + x
            end
            return sum
        end, { 1, 2, 3 })
        out(v)
    end)
    assertx(out(), "6\n")
    atmos.stop()
end

do
    print("Testing...", "xspawn 7: string operations (string lib available)")
    loop(function ()
        local v = xspawn(function (s)
            return string.upper(s)
        end, "hello world")
        out(v)
    end)
    assertx(out(), "HELLO WORLD\n")
    atmos.stop()
end

do
    print("Testing...", "xspawn 8: math operations (math lib available)")
    loop(function ()
        local v = xspawn(function (n)
            return math.sqrt(n)
        end, 9)
        out(v)
    end)
    assertx(out(), "3.0\n")
    atmos.stop()
end

print "--- XSPAWN / UPVALUES ---"

do
    print("Testing...", "xspawn 9: upvalue - pure function")
    loop(function ()
        local function double (n)
            return n * 2
        end
        local v = xspawn(function (n)
            return double(n)
        end, 21)
        out(v)
    end)
    assertx(out(), "42\n")
    atmos.stop()
end

do
    print("Testing...", "xspawn 10: upvalue - value")
    loop(function ()
        local multiplier = 3
        local v = xspawn(function (n)
            return n * multiplier
        end, 10)
        out(v)
    end)
    assertx(out(), "30\n")
    atmos.stop()
end

print "--- XSPAWN / ERROR PROPAGATION ---"

do
    print("Testing...", "xspawn 11: error inside lane propagates")
    local _,err = pcall(function ()
        loop(function ()
            xspawn(function ()
                error("lane error")
            end)
        end)
    end)
    assertfx(tostring(err), "lane error")
    atmos.stop()
end

print "--- XSPAWN / LIFECYCLE ---"

do
    print("Testing...", "xspawn 12: parent task suspends during xspawn")
    loop(function ()
        out("before")
        xspawn(function ()
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
    print("Testing...", "xspawn 13: sequential xspawns")
    loop(function ()
        local a = xspawn(function (x) return x + 1 end, 10)
        local b = xspawn(function (x) return x + 2 end, 20)
        out(a, b)
    end)
    assertx(out(), "11\t22\n")
    atmos.stop()
end

do
    print("Testing...", "xspawn 14: xspawn inside par_or")
    loop(function ()
        local v = par_or(
            function ()
                return xspawn(function () return "from xspawn" end)
            end,
            function ()
                await(false)
            end
        )
        out(v)
    end)
    assertx(out(), "from xspawn\n")
    atmos.stop()
end

print "--- XSPAWN / ISOLATION ---"

do
    print("Testing...", "xspawn 15: table isolation - mutation in lane does not affect parent")
    loop(function ()
        local t = { 1, 2, 3 }
        local v = xspawn(function (t)
            t[1] = 999
            return t[1]
        end, t)
        out(v)
        out(t[1])
    end)
    assertx(out(), "999\n1\n")
    atmos.stop()
end

print "--- XTASK / REUSE ---"

do
    print("Testing...", "xtask 2: reuse prototype")
    loop(function ()
        local xt = xtask(function (n)
            return n * n
        end)
        local a = xspawn(xt, 3)
        local b = xspawn(xt, 7)
        out(a, b)
    end)
    assertx(out(), "9\t49\n")
    atmos.stop()
end

do
    print("Testing...", "xtask 3: prototype with upvalue")
    loop(function ()
        local base = 100
        local xt = xtask(function (n)
            return base + n
        end)
        local v = xspawn(xt, 42)
        out(v)
    end)
    assertx(out(), "142\n")
    atmos.stop()
end
