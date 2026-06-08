require "atmos.env.clock"
local S = require "atmos.streams"

loop(function ()
    local s1 = S.fr_await(1*_s_)
        :tap(function()
            print("Hello World!")
        end)
    local s2 = S.fr_await(5*_s_):take(1)
    S.paror(s1,s2):to()
end)
