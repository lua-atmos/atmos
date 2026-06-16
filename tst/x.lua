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

do
    print("Testing...", "is 2")
    do
        out(X.is('x.y.z', 'x.y'))   -- string hierarchy
        out(X.is('x.y', 'x.y.z'))   -- not a super-tag
        out(X.is(10, 'number'))     -- type name
        out(X.is('x', 'x'))         -- identity
        out(X.is({}, {}))           -- distinct tables (catch-trap case)
        out(X.is({tag='X'}, 'X'))   -- tagged table vs tag
    end
    assertx(out(), "true\nfalse\ntrue\ntrue\nfalse\ntrue\n")
end

print "--- GTE ---"

do
    print("Testing...", "gte 1: scalars")
    do
        out(X.gte('x', 'x.y'))      -- super-tag
        out(X.gte('x.y', 'x'))      -- not super
        out(X.gte('x', 'x'))        -- identity
        out(X.gte(1, 1))            -- identity
        out(X.gte(1, 2))            -- distinct numbers
    end
    assertx(out(), "true\nfalse\ntrue\ntrue\nfalse\n")
end

do
    print("Testing...", "gte 2: tables")
    do
        out(X.gte({tag='x'},      {tag='x', v=1}))   -- b has extras
        out(X.gte({tag='x', v=1}, {tag='x'}))        -- b misses v
        out(X.gte({},             {a=1}))            -- empty super
        out(X.gte({a=1},          {}))               -- b misses a
    end
    assertx(out(), "true\nfalse\ntrue\nfalse\n")
end

print "--- EQ ---"

do
    print("Testing...", "eq 1")
    do
        out(X.eq({1,2},  {1,2}))    -- equal vector
        out(X.eq({1,2},  {2,1}))    -- order matters
        out(X.eq({a=1},  {a=1}))    -- equal record
        out(X.eq({a=1},  {a=2}))    -- different value
        out(X.eq(1,      1))        -- scalar
        out(X.eq('x',    'x'))      -- string
    end
    assertx(out(), "true\nfalse\ntrue\nfalse\ntrue\ntrue\n")
end

print "--- XIN ---"

do
    print("Testing...", "xin 1: value / key")
    do
        out(X.xin(20,  {10,20,30}))   -- value in vector
        out(X.xin(99,  {10,20,30}))   -- absent
        out(X.xin('x', {x=10}))       -- named key
        out(X.xin(10,  {x=10}))       -- value
        out(X.xin('y', {x=10}))       -- absent
    end
    assertx(out(), "true\nfalse\ntrue\ntrue\nfalse\n")
end

do
    print("Testing...", "xin 2: hierarchy / range")
    do
        out(X.xin('X',   {'X.A'}))    -- :X in [:X.A]  (X.A is-a X)
        out(X.xin('X.A', {'X'}))      -- :X.A not in [:X]
        out(X.xin(3, 5))              -- 3 in range 1..5
        out(X.xin(6, 5))              -- 6 out of range
    end
    assertx(out(), "true\nfalse\ntrue\nfalse\n")
end
