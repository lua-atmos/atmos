-- Mock JS host: simulate js_now() with os.clock()
js_now = function ()
    return math.floor(os.clock() * 1000)
end

local env = require "atmos.env.js"

start(function ()
    print("now", env.now)
    watching(clock{s=5}, function ()
        every(clock{ms=500}, function ()
            print("Hello World!")
        end)
    end)
    print("now", env.now)
    stop()
end)

-- Mock JS event loop: tick until done
while env.running do
    env.tick()
end
