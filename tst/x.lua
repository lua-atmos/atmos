local atmos = require "atmos"
require "test"
local X = require "atmos.x"

print "--- IS ---"

do
    print("Testing...", "is 1")
    do
        out(X.is({tag='x.y.z'}, 'x.y'))
        out(X.is({tag='x'},     'x.y'))
        out(X.is({tag={}},      ''))
    end
    assertx(out(), "true\nfalse\nfalse\n")
end
