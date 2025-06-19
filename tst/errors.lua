local atmos = require "atmos"
require "test"

do
    print("Testing...", "throw 1")
    do
        call(function ()
            spawn(function ()
                await(spawn(function ()
                    await(true)
                end))
                throw "OK"
            end)
            emit('X')
        end)
    end
    assertx(out(), "0\n1\n2\n")
    atmos.close()
end
