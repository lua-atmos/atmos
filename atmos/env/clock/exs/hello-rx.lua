require "atmos.env.clock"
local S = require "atmos.streams"

call(function ()
    local s1 = S.from(clock{s=1})
        :tap(function()
            print("Hello World!")
        end)
    local s2 = S.from(clock{s=5}):take(1)
    S.paror(s1,s2):to()
end)
