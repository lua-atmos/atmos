require "atmos.env.clock"
local S = require "atmos.streams"

call(function ()
    local s1 = S.fr_await(clock{s=1})
    local s2 = S.take(s1, 5)
    local s3 = S.to_each(s2,
        function ()
            print("Hello World!")
        end
    )
end)

-- from(@1) --> take(1) --> to_each --> \{print "Hello World"}
-- fr_await(@1) --> take(1) --> to_each --> \{print "Hello World"}
