local atmos = require "atmos"
require "test"

print "--- DEFER ---"

do
    print("Testing...", "defer 1")
    do
        local _ <close> = defer(function()
            out(1)
        end)
        local _ <close> = defer(function()
            out(2)
        end)
    end
    assertx(out(), "2\n1\n")
    atmos.close()
end

do
    print("Testing...", "task pin 1")
    out(1)
    do
        out(2)
        local _ <close> = spawn (function ()
            local _ <close> = defer(function ()
                out("defer")
            end)
            await(true)
        end)
        out(3)
    end
    out(4)
    assertx(out(), "1\n2\n3\ndefer\n4\n")
    atmos.close()
end

do
    print("Testing...", "task pin 2")
    out(1)
    do
        out(2)
        local _ <close> = spawn (function ()
            local _ <close> = defer(function ()
                out("defer")
            end)
            await(true)
        end)
        out(3)
    end
    out(4)
    assertx(out(), "1\n2\n3\ndefer\n4\n")
    atmos.close()
end

do
    print("Testing...", "nested task 1")
    call(nil, function ()
        spawn(function ()
            spawn(function ()
                local _ <close> = defer(function ()
                    out "nested task aborted"
                end)
                await(false)    -- never awakes
            end)
        end)
    end)
    assertx(out(), "nested task aborted\n")
    atmos.close()
end

do
    print("Testing...", "nested task 2")
    spawn(function ()
        spawn(function ()
            local _ <close> = defer(function ()
                out "nested task aborted"
            end)
            await(false)    -- never awakes
        end)
    end)
    assertx(out(), "nested task aborted\n")
    atmos.close()
end

print "--- THROW / CATCH ---"

do
    print("Testing...", "catch 1")
    do
        out(1)
        catch ('X', function ()
            out(2)
            throw ('X')
            out(3)
        end)
        out(4)
    end
    assertx(out(), "1\n2\n4\n")
    atmos.close()
end

do
    print("Testing...", "catch 2")
    do
        out(1)
        catch ('X', function ()
            out(2)
            throw('X')
            out(3)
        end)
        out(4)
    end
    assertx(out(), "1\n2\n4\n")
    atmos.close()
end

do
    print("Testing...", "catch 3")
    local ok,v = catch(true, function ()
        out(1)
        catch ('X', function ()
            out(2)
            throw()
            out(3)
        end)
        out(4)
    end)
    out(ok,v)
    assertx(out(), "1\n2\nfalse\tnil\n")
    atmos.close()
end

do
    print("Testing...", "catch 4")
    do
        out(1)
        catch (true, function ()
            out(2)
            throw()
            out(3)
        end)
        out(4)
    end
    assertx(out(), "1\n2\n4\n")
    atmos.close()
end

do
    print("Testing...", "catch 5")
    do
        out(1)
        catch('Y', function ()
            out(2)
            catch('X', function ()
                out(3)
                throw('Y')
                out(4)
            end)
            out(5)
        end)
        out(6)
    end
    assertx(out(), "1\n2\n3\n6\n")
    atmos.close()
end

do
    print("Testing...", "catch 6")
    do
        out(1)
        catch ('X', --[[function (e,v1,v2) return v2==20 end,]] function ()
            out(2)
            catch ('X', --[[function (e,v1,v2) return v1~=10 end,]] function ()
                out(3)
                throw('X',10,20)
                out(4)
            end)
            out(5)
        end)
        out(6)
    end
    --assertx(out(), "1\n2\n3\n6\n")
    assertx(out(), "1\n2\n3\n5\n6\n")
    atmos.close()
end

do
    print("Testing...", "catch 7")
    do
        local ok,v1,v2 = catch(true, function ()
            throw(10,20)
        end)
        out(ok,v1,v2)
    end
    assertx(out(), "false\t10\t20\n")
    atmos.close()
end

do
    print("Testing...", "catch 8")
    do
        local ok,v = catch(true, function ()
            return (10)
        end)
        out(ok,v)
    end
    assertx(out(), "true\t10\n")
    atmos.close()
end

do
    print("Testing...", "catch 9")
    do
        local a = 1
        catch('X', function ()
            local b = 2
            out(a+b)
        end)
    end
    assertx(out(), "3\n")
    atmos.close()
end

do
    print("Testing...", "catch 10")
    local ok,v = catch(function() return true end, function ()
        out(1)
        catch ('X', function ()
            out(2)
            throw()
            out(3)
        end)
        out(4)
    end)
    out(ok,v)
    assertx(out(), "1\n2\nfalse\tnil\n")
    atmos.close()
end

do
    print("Testing...", "catch 11")
    local ok,v = catch(function(a,b) if a=='X' then return true,b end end, function ()
        out(1)
        catch (function () return false end, function ()
            out(2)
            throw('X','Y')
            out(3)
        end)
        out(4)
    end)
    out(ok,v)
    assertx(out(), "1\n2\nfalse\tY\n")
    atmos.close()
end

print "-=- TASK -=-"

do
    print("Testing...", "task 1")
    do
        spawn(function ()
            local x,y,z = catch('X', function ()
                await(true)
                throw('X',10)
            end)
            out(x, y, z)
        end)
        emit()
        out('ok')
    end
    assertx(out(), "false\tX\t10\nok\n")
    atmos.close()
end

do
    print("Testing...", "task 2")
    do
        spawn(function ()
            local x,y,z = catch('X', function ()
                spawn (function ()
                    await(true)
                    throw('X',10)
                end)
                await(false)
            end)
            out(x, y, z)
        end)
        emit()
        out('ok')
    end
    assertx(out(), "false\tX\t10\nok\n")
    atmos.close()
end

print "-=- CALL -=-"

do
    print("Testing...", "call 1")
    do
        local v = call(nil, function ()
            return 1
        end)
        out(v)
    end
    assertx(out(), "1\n")
    atmos.close()
end

do
    print("Testing...", "call 2")
    do
        local function step ()
            emit 'X'
        end
        local v = call({init=function()end,step=step}, function ()
            await 'X'
            return 1
        end)
        out(v)
    end
    assertx(out(), "1\n")
    atmos.close()
end

--[[
do
    print("Testing...", "call 4: err")
    do
        local v = call({}, function ()
            throw 'X'
            return 1
        end)
        out(v)
    end
    assertx(out(), "1\n")
    atmos.close()
end

do
    print("Testing...", "call 5: err")
    do
        local function step ()
            emit 'X'
        end
        local v = call({step}, function ()
            await 'X'
            throw 'X'
        end)
        out(v)
    end
    assertx(out(), "1\n")
    atmos.close()
end

do
    print("Testing...", "call 6: err")
    do
        local function step ()
            throw 'X'
        end
        local v = call({step}, function ()
            await 'X'
        end)
        out(v)
    end
    assertx(out(), "1\n")
    atmos.close()
end
]]
