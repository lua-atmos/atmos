local SDL = require "SDL"
require "atmos"
local sdl = require "atmos.env.sdl"

sdl.loop(nil, function ()
    watching(clock{s=5}, function ()
        every(clock{s=1}, function ()
            print("Hello World!")
        end)
    end)
end)
