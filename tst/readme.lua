require "atmos.env.clock"
local S = require "atmos.streams"

loop(function ()

    print "-=- 1 -=-"
    do
        watching(5*_s_, function ()
            loop_on(1*_s_, function ()
                print("Hello World!")
            end)
        end)
    end

    print "-=- 2 -=-"
    do
        local s1 = S.on(1*_s_)
            :tap(function()
                print("Hello World!")
            end)
        local s2 = S.on(5*_s_):take(1)
        S.parany(s1,s2):to()
    end
end)
