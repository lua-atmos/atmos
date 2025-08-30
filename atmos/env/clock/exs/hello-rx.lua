require "atmos.env.clock"
local S = require "atmos.streams"

call(function ()
    local s1 = S.from(clock{s=5}):take(1)
    local s2 = S.from(clock{s=1})
    s1:paror(s2)
        :to_each(function()
            print("Hello World!")
        end)
end)

-- from(@1) --> take(1) --> to_each --> \{print "Hello World"}
-- fr_await(@1) --> take(1) --> to_each --> \{print "Hello World"}
