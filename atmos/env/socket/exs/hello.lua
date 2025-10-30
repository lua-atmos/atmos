local env = require "atmos.env.socket"

call(function ()
    print("now", env.now)
    watching(clock{s=5}, function ()
        every(clock{ms=500}, function ()
            print("Hello World!")
        end)
    end)
    print("now", env.now)
end)
