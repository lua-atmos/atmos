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
    print("Testing...", "thread 7: string operations (string lib available)")
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
    print("Testing...", "thread 8: math operations (math lib available)")
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
    print("Testing...", "thread 15: table isolation - mutation in lane does not affect parent")
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
    print("Testing...", "thread 16: prototype reuse (same fn, multiple calls)")
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
    print("Testing...", "thread 17: cache hit with updated upvalue")
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

print "--- THREAD / FORBIDDEN ---"

do
    print("Testing...",
        "thread 18: await forbidden inside thread")
    local _,err = pcall(function ()
        spawn(function ()
            thread(function ()
                await(true)
            end)
        end)
        os.execute("sleep 0.1")
        emit()
    end)
    assertfx(tostring(err[1]), "attempt to call a nil value %(global 'await'%)")
    atmos.stop()
end

do
    print("Testing...",
        "thread 19: spawn forbidden inside thread")
    local _,err = pcall(function ()
        spawn(function ()
            thread(function ()
                spawn(function () end)
            end)
        end)
        os.execute("sleep 0.1")
        emit()
    end)
    assertfx(tostring(err[1]), "attempt to call a nil value %(global 'spawn'%)")
    atmos.stop()
end

do
    print("Testing...",
        "thread 20: par_or forbidden inside thread")
    local _,err = pcall(function ()
        spawn(function ()
            thread(function ()
                par_or(
                    function () end,
                    function () end
                )
            end)
        end)
        os.execute("sleep 0.1")
        emit()
    end)
    assertfx(tostring(err[1]), "attempt to call a nil value %(global 'par_or'%)")
    atmos.stop()
end

print "--- THREAD / CANCEL ---"

do
    print("Testing...", "thread 21: cancel - par_or cancels sleeping thread")
    spawn(function ()
        local cleaned = false
        local v = par_or(
            function ()
                local _ <close> = defer(function ()
                    cleaned = true
                end)
                return thread(function ()
                    os.execute("sleep 1")
                    return "slow"
                end)
            end,
            function ()
                return "fast"
            end
        )
        out(v)
        out(cleaned)
    end)
    os.execute("sleep 0.1")
    emit()
    assertx(out(), "fast\ntrue\n")
    atmos.stop()
end

do
    print("Testing...", "thread 22: cancel - watching cancels sleeping thread")
    spawn(function ()
        local cleaned = false
        local v = watching("stop",
            function ()
                local _ <close> = defer(function ()
                    cleaned = true
                end)
                thread(function ()
                    os.execute("sleep 1")
                    return "slow"
                end)
            end
        )
        out(v)
        out(cleaned)
    end)
    os.execute("sleep 0.1")
    emit("stop")
    assertx(out(), "stop\ntrue\n")
    atmos.stop()
end

do
    print("Testing...", "thread 23: cancel - parent death cancels thread")
    local cleaned = false
    spawn(function ()
        spawn(function ()
            local _ <close> = defer(function ()
                cleaned = true
            end)
            thread(function ()
                os.execute("sleep 1")
                return "slow"
            end)
        end)
        out("parent done")
    end)
    out(cleaned)
    assertx(out(), "parent done\ntrue\n")
    atmos.stop()
end

do
    print("Testing...", "thread 24: cancel - defer fires inside lane body")
    spawn(function ()
        local v = thread(function ()
            local log = { "start" }
            do
                local d <close> = setmetatable(
                    {},
                    { __close = function ()
                        log[#log + 1] = "cleanup"
                    end }
                )
                os.execute("sleep 0.1")
                log[#log + 1] = "done"
            end
            return table.concat(log, ",")
        end)
        out(v)
    end)
    os.execute("sleep 0.3")
    emit()
    assertx(out(), "start,done,cleanup\n")
    atmos.stop()
end

--[[
do
    print("Testing...", "thread 25: cancel - defer fires inside lane body on cancel")
    local marker = os.tmpname()
    spawn(function ()
        spawn(function ()
            local defer = defer
            thread(function ()
                local _ <close> = setmetatable({}, {
                    __close = function ()
                        local fh = io.open(marker, "w")
                        fh:write("cancelled")
                        fh:close()
                    end
                })
                while true do end
            end)
        end)
    end)
    local fh = io.open(marker, "r")
    local content = fh and fh:read("a") or ""
    if fh then fh:close() end
    os.remove(marker)
    assertx(content, "cancelled")
    atmos.stop()
end
]]
