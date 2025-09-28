require "atmos.env.clock"
local S = require "atmos.streams"

call(function ()

    print "-=- 1 -=-"
    do
        watching(clock{s=1}, function ()
            every(clock{ms=200}, function ()
                print("Hello World!")
            end)
        end)
    end

    print "-=- 2 -=-"
    do
        local s1 = S.from(clock{ms=200})
            :tap(function()
                print("Hello World!")
            end)
        local s2 = S.from(clock{s=1}):take(1)
        S.paror(s1,s2):to()
    end
end)
