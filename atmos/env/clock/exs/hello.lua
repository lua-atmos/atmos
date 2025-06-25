require "atmos.env.clock"

loop(function ()
    watching(clock{s=5}, function ()
        every(clock{s=1}, function ()
            print("Hello World!")
        end)
    end)
end)
