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
    print("Testing...", "throw 1")
    local out = exec [[
        do
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
            out('ok')
        end
    ]]
    assertx(trim(out), trim [[
        ==> ERROR:
         |  /tmp/err.lua:12 (emit)
         v  /tmp/err.lua:6 (throw) <- /tmp/err.lua:4 (task) <- /tmp/err.lua:2 (task)
        ==> X, 10
    ]])
end

do
    print("Testing...", "throw 2")
    local out = exec [[
        call({}, function ()
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
    ]]
    assertx(trim(out), trim [[
        ==> ERROR:
         |  /tmp/err.lua:1 (call)
         |  /tmp/err.lua:11 (emit) <- /tmp/err.lua:1 (task)
         v  /tmp/err.lua:7 (throw) <- /tmp/err.lua:3 (task) <- /tmp/err.lua:2 (task) <- /tmp/err.lua:1 (task)
        ==> OK
    ]])
end

do
    print("Testing...", "throw 3")
    local out = exec [[
        call({}, function ()
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
        end)
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
        function T ()
            spawn (function ()
                throw 'X'
            end)
        end

        call({}, function ()  
            spawn(function ()
                local ok, err = catch('Y', function ()
                    spawn(T)
                end)
                print(ok, err)
            end)
        end)  
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
        function T ()
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
        emit('X')
    ]]
    assertx(trim(out), trim [[
        ==> ERROR:
        |  /tmp/err.lua:24 (emit)
        |  /tmp/err.lua:20 (emit) <- /tmp/err.lua:18 (task) <- /tmp/err.lua:12 (task)
        v  /tmp/err.lua:6 (throw) <- /tmp/err.lua:15 (task) <- /tmp/err.lua:13 (tasks) <- /tmp/err.lua:12 (task)
        ==> OK
    ]])
end

do
    print "TODO: error w/o throw"
    print("Testing...", "error 1")
    local out = exec [[
        call({}, function ()
            local x = 1 + true
        end)
    ]]
    assertx(trim(out), trim [[
        ==> ERROR:
        |  /tmp/err.lua:1 (call)
        v  /tmp/err.lua:1 (throw)
        ==> /tmp/err.lua:2: attempt to perform arithmetic on a boolean value
    ]])
end
