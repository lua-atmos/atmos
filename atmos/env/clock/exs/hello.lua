local env = require "atmos.env.clock"

loop(function ()
    print("now", env.now)
    watching(5*_s_, function ()
        every(500*_ms_, function ()
            print("Hello World!")
        end)
    end)
    print("now", env.now)
end)
