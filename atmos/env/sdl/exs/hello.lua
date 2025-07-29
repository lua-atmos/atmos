require "atmos.env.sdl"

call(function ()
    watching(clock{s=5}, function ()
        every(clock{ms=500}, function ()
            print("Hello World!")
        end)
    end)
end)
