local atmos = require "atmos"
require "test"

print "--- ENVS: QUIT ---"

do
    print("Testing...", "quit: single env")
    local q = false
    local function step ()
        emit 'X'
    end
    local function quit ()
        q = true
    end
    atmos.env { step=step, quit=quit }
    loop(function ()
        await 'X'
    end)
    out(q)
    assertx(out(), "true\n")
    atmos.stop()
end

do
    print("Testing...", "quit: on error")
    local q = false
    local function step ()
        emit 'X'
    end
    local function quit ()
        q = true
    end
    atmos.env { step=step, quit=quit }
    pcall(function ()
        loop(function ()
            await 'X'
            out 'err'
            throw 'ERR'
        end)
    end)
    out(q)
    assertx(out(), "err\ntrue\n")
    atmos.stop()
end

do
    print("Testing...", "quit: two envs, reverse order")
    local order = ""
    local n = 0
    local function step1 ()
        n = n + 1
        emit 'X'
    end
    local function step2 ()
    end
    atmos.env { step=step1, quit=function() order = order .. "1" end, mode={ primary=true, secondary=false } }
    atmos.env { step=step2, quit=function() order = order .. "2" end, mode={ primary=false, secondary=true } }
    loop(function ()
        await 'X'
    end)
    out(order)
    assertx(out(), "21\n")
    atmos.stop()
end

print "--- ENVS: ERRORS ---"

do
    print("Testing...", "error: no mode on primary")
    local ok, err = pcall(function ()
        atmos.env { step=function() end }
        atmos.env { step=function() end }
    end)
    out(ok)
    assertx(out(), "false\n")
    assertfx(err, "first env must support primary mode")
    atmos.stop()
end

do
    print("Testing...", "error: single-env then multi-env")
    local ok, err = pcall(function ()
        atmos.env { step=function() end, mode={ primary=true, secondary=false } }
        atmos.env { step=function() end }
    end)
    out(ok)
    assertx(out(), "false\n")
    assertfx(err, "non%-first envs must support secondary mode")
    atmos.stop()
end

do
    print("Testing...", "error: primary without primary mode")
    local ok, err = pcall(function ()
        atmos.env { step=function() end, mode={ primary=false, secondary=true } }
        atmos.env { step=function() end, mode={ primary=false, secondary=true } }
    end)
    out(ok)
    assertx(out(), "false\n")
    assertfx(err, "first env must support primary mode")
    atmos.stop()
end

do
    print("Testing...", "error: secondary without secondary mode")
    local ok, err = pcall(function ()
        atmos.env { step=function() end, mode={ primary=true, secondary=false } }
        atmos.env { step=function() end, mode={ primary=true, secondary=false } }
    end)
    out(ok)
    assertx(out(), "false\n")
    assertfx(err, "non%-first envs must support secondary mode")
    atmos.stop()
end

print "--- ENVS: MULTI-ENV EXAMPLE ---"

do
    print("Testing...", "multi-env: primary + secondary")
    local n = 0
    local function step1 ()
        n = n + 1
        emit('sensor', n)
        emit('clock', 100, n*100)
    end
    local function step2 ()
        emit('net', n*10)
    end
    atmos.env { step=step1, mode={ primary=true, secondary=false } }
    atmos.env { step=step2, mode={ primary=false, secondary=true } }
    loop(function ()
        local _, s = await 'sensor'
        local _, x = await 'net'
        out(s, x)
    end)
    assertx(out(), "1\t10\n")
    atmos.stop()
end

print "--- ENVS: __ATMOS ---"

do
    print("Testing...", "atmos nil opt-out")
    do
        local meta = { __atmos = function () return nil end }
        atmos.env { step = function ()
            emit(setmetatable({tag='X'}, meta))
        end }
        local v = loop(function ()
            await 'X'
            return 1
        end)
        out(v)
    end
    assertx(out(), "1\n")
    atmos.stop()
end

do
    print("Testing...", "atmos true")
    do
        local meta = { __atmos = function () return true end }
        atmos.env { step = function ()
            emit(setmetatable({}, meta))
        end }
        local v = loop(function ()
            await 'X'
            return 1
        end)
        out(v)
    end
    assertx(out(), "1\n")
    atmos.stop()
end

do
    print("Testing...", "atmos false short-circuit")
    do
        local meta = { __atmos = function () return false end }
        local n = 0
        atmos.env { step = function ()
            n = n + 1
            if n == 1 then
                emit(setmetatable({tag='X'}, meta))
            elseif n == 2 then
                emit 'X'
            end
        end }
        loop(function ()
            await 'X'
            out(n)
        end)
    end
    assertx(out(), "2\n")
    atmos.stop()
end

do
    print("Testing...", "atmos mta nil opt-out")
    do
        local meta = { __atmos = function () return nil end }
        atmos.env { step = function ()
            emit 'X'
        end }
        local pat = setmetatable({'==', 'X'}, meta)
        local v = loop(function ()
            await(pat)
            return 1
        end)
        out(v)
    end
    assertx(out(), "1\n")
    atmos.stop()
end

do
    print("Testing...", "atmos mta true")
    do
        local meta = { __atmos = function () return true end }
        atmos.env { step = function ()
            emit 'X'
        end }
        local pat = setmetatable({}, meta)
        local v = loop(function ()
            await(pat)
            return 1
        end)
        out(v)
    end
    assertx(out(), "1\n")
    atmos.stop()
end

do
    print("Testing...", "atmos mta false short-circuit")
    do
        local meta = { __atmos = function () return false end }
        local n = 0
        atmos.env { step = function ()
            n = n + 1
            emit 'X'
        end }
        local pat = setmetatable({'==', 'X'}, meta)
        loop(function ()
            par_or(
                function () await(pat); out 'woke' end,
                function () for i=1,3 do await(true) end; out('n='..n) end
            )
        end)
    end
    assertx(out(), "n=3\n")
    atmos.stop()
end
