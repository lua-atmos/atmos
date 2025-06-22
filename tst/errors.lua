local atmos = require "atmos"
require "test"

do
    print("Testing...", "throw 1")
    do
        function T ()
            await(spawn(function ()
                await('Y')
            end))
            local function f ()
                return 1 + true
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
    end
    assertx(out(), "0\n1\n2\n")
    atmos.close()
end

do
    print("Testing...", "task 3: error")
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
    assertfx(out(), "==> X, 10")
    atmos.close()
end

do
    print("Testing...", "throw 1")
    do
        call(function ()
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
    end
    assertx(out(), "0\n1\n2\n")
    atmos.close()
end

do
    print("Testing...", "throw 1")
    do
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
    end
    assertx(out(), "0\n1\n2\n")
    atmos.close()
end
