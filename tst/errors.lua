local atmos = require "atmos"
require "test"

function trim (s)
    return (s:gsub("^%s*",""):gsub("\n%s*","\n"):gsub("%s*$",""))
end

function exec (src)
    src = 'require "atmos" ; require "test" ; ' .. src
    local f = io.open("/tmp/err.lua", 'w')
    f:write(src)
    local h = io.popen("lua5.4 /tmp/err.lua 2>&1")
    return h:read('*a')
end

do
    print("Testing...", "error 1")
    local out = exec [[
        local _, err = pcall(function ()
            call(function ()
                error 'OK'
            end)
        end)
        print(err)
    ]]
    assertx(trim(out), trim [[
        ==> ERROR:
         |  /tmp/err.lua:2 (call)
         v  /tmp/err.lua:3 (throw)
        ==> OK
    ]])
end

do
    print("Testing...", "error 2")
    local out = exec [[
        local _, err = pcall(function ()
            call(function ()
                print(1 + true)
            end)
        end)
        print(err)
    ]]
    assertx(trim(out), trim [[
        ==> ERROR:
         |  /tmp/err.lua:2 (call)
         v  /tmp/err.lua:3 (throw)
        ==> attempt to perform arithmetic on a boolean value
    ]])
end

do
    print("Testing...", "throw 1")
    local out = exec [[
        local _, err = pcall(function ()
            call(function ()
                spawn(function ()
                    local x,y,z = catch('Z', function ()
                        spawn (function ()
                            await(true)
                            throw('X',10)
                        end)
                        await(false)
                    end)
                    out(x, y, z)
                end)
                emit()
            end)
            out('ok')
        end)
        print(err)
    ]]
    assertx(trim(out), trim [[
        ==> ERROR:
         |  /tmp/err.lua:2 (call)
         |  /tmp/err.lua:13 (emit) <- /tmp/err.lua:2 (task)
         v  /tmp/err.lua:7 (throw) <- /tmp/err.lua:5 (task) <- /tmp/err.lua:3 (task) <- /tmp/err.lua:2 (task)
        ==> X, 10
    ]])
end

do
    print("Testing...", "throw 2")
    local out = exec [[
        local _, err = pcall(function ()
            call(function ()
                spawn(function ()
                    spawn(function ()
                        await(spawn(function ()
                            await(true)
                        end))
                        throw "OK"
                    end)
                    await(false)
                end)
                emit('X')
            end)
        end)
        print(err)
    ]]
    assertx(trim(out), trim [[
        ==> ERROR:
         |  /tmp/err.lua:2 (call)
         |  /tmp/err.lua:12 (emit) <- /tmp/err.lua:2 (task)
         v  /tmp/err.lua:8 (throw) <- /tmp/err.lua:4 (task) <- /tmp/err.lua:3 (task) <- /tmp/err.lua:2 (task)
        ==> OK
    ]])
end

do
    print("Testing...", "throw 3")
    local out = exec [[
        local _, err = pcall(function () call(function ()
            spawn(function ()
                spawn(true,function ()
                    await(spawn(function ()
                        await('Y')
                    end))
                    throw "OK"
                end)
                spawn(true,function ()
                    await('X')
                    emit('Y')
                end)
                await(false)
            end)
            emit('X')
        end) end)
        print(err)
    ]]
    assertx(trim(out), trim [[
        ==> ERROR:
        |  /tmp/err.lua:1 (call)
        |  /tmp/err.lua:15 (emit) <- /tmp/err.lua:1 (task)
        |  /tmp/err.lua:11 (emit) <- /tmp/err.lua:9 (task) <- /tmp/err.lua:2 (task) <- /tmp/err.lua:1 (task)
        v  /tmp/err.lua:7 (throw) <- /tmp/err.lua:3 (task) <- /tmp/err.lua:2 (task) <- /tmp/err.lua:1 (task)
        ==> OK
    ]])
end

do
    print("Testing...", "throw 4")

    local out = exec [[
        local _, err = pcall(function () function T ()
            spawn (function ()
                throw 'X'
            end)
        end

        call(function ()
            spawn(function ()
                local ok, err = catch('Y', function ()
                    spawn(T)
                end)
                print(ok, err)
            end)
        end) end)
        print(err)
    ]]
    assertx(trim(out), trim [[
        ==> ERROR:
        |  /tmp/err.lua:7 (call)
        v  /tmp/err.lua:3 (throw) <- /tmp/err.lua:2 (task) <- /tmp/err.lua:10 (task) <- /tmp/err.lua:8 (task) <- /tmp/err.lua:7 (task)
        ==> X
    ]])
end

do
    print("Testing...", "tasks 1")
    local out = exec [[
        local _, err = pcall(function () function T ()
            await(spawn(function ()
                await('Y')
            end))
            local function f ()
                throw 'OK'
            end
            f()
            --error "OK"
            --throw "OK"
        end
        call(function ()
            spawn(function ()
                local ts = tasks()
                spawn(true,function ()
                    spawn_in(ts, T)
                    await(false)
                end)
                spawn(true,function ()
                    await('X')
                    emit('Y')
                end)
                await(false)
            end)
            emit('X') end)
        end)
        print(err)
    ]]
    assertx(trim(out), trim [[
        ==> ERROR:
        |  /tmp/err.lua:12 (call)
        |  /tmp/err.lua:25 (emit) <- /tmp/err.lua:12 (task)
        |  /tmp/err.lua:21 (emit) <- /tmp/err.lua:19 (task) <- /tmp/err.lua:13 (task) <- /tmp/err.lua:12 (task)
        v  /tmp/err.lua:6 (throw) <- /tmp/err.lua:16 (task) <- /tmp/err.lua:14 (tasks) <- /tmp/err.lua:13 (task) <- /tmp/err.lua:12 (task)
        ==> OK
    ]])
end

do
    print "TODO: error w/o throw"
    print("Testing...", "error 1")
    local out = exec [[
        local _, err = pcall(function ()
            call(function ()
                local x = 1 + true
            end)
        end)
        print(err)
    ]]
    assertx(trim(out), trim [[
        ==> ERROR:
        |  /tmp/err.lua:2 (call)
        v  /tmp/err.lua:3 (throw)
        ==> attempt to perform arithmetic on a boolean value
    ]])
end

do
    print("Testing...", "tasks 2")
    local out = exec [[
        local _, err = pcall(function ()
            call(function ()
                local x = 1 + true
            end)
        end)
        print(err)
    ]]
    assertx(trim(out), trim [[
        ==> ERROR:
        |  /tmp/err.lua:2 (call)
        v  /tmp/err.lua:3 (throw)
        ==> attempt to perform arithmetic on a boolean value
    ]])
end

do
    print("Testing...", "spawn termination")
    local out = exec [[
        local _, err = pcall(function ()
            call(function ()
                spawn(function ()
                    await(spawn(function() await('X') end))
                    print(1+true)
                end)
                emit 'X'
            end)
        end)
        print(err)
    ]]
    assertx(trim(out), trim [[
        ==> ERROR:
         |  /tmp/err.lua:2 (call)
         |  /tmp/err.lua:7 (emit) <- /tmp/err.lua:2 (task)
         v  /tmp/err.lua:5 (throw) <- /tmp/err.lua:2 (task)
        ==> attempt to perform arithmetic on a boolean value
    ]])
end

do
    print("Testing...", "clock external error")
    local out = exec [[
        local _, err = pcall(function ()
            call(function ()
                require "atmos.env.clock"
                local _ <close> = spawn(true, (function ()
                    await(clock {h=0,min=0,s=0,ms=1 })
                    emit("X")
                end))
                await("X")
                throw("err")
            end)
        end)
        print(err)
    ]]
    assertx(trim(out), trim [[
        ==> ERROR:
         |  /tmp/err.lua:2 (call)
         |  ../atmos/env/clock/init.lua:12 (emit)
         |  /tmp/err.lua:6 (emit) <- /tmp/err.lua:4 (task) <- /tmp/err.lua:2 (task)
         v  /tmp/err.lua:9 (throw) <- /tmp/err.lua:2 (task)
        ==> err
    ]])
end
