require "atmos.env.clock"
local S = require "atmos.streams"

loop(function ()

    print "-=- 1 -=-"
    do
        watching(1*_s_, function ()
            loop_on(200*_ms_, function ()
                print("Hello World!")
            end)
        end)
    end

    print "-=- 2 -=-"
    do
        local s1 = S.on(200*_ms_)
            :tap(function()
                print("Hello World!")
            end)
        local s2 = S.on(1*_s_):take(1)
        S.paror(s1,s2):to()
    end
end)
