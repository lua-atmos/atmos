require "atmos.env.clock"
local S = require "atmos.streams"

call(function ()
    S.fr_awaits(clock{s=1})
        :take(5)
        :to_each(function()
            print("Hello World!")
        end)
end)

-- from(@1) --> take(1) --> to_each --> \{print "Hello World"}
-- fr_await(@1) --> take(1) --> to_each --> \{print "Hello World"}
