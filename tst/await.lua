local atmos = require "atmos"
require "test"

print "--- AWAIT / _OR_ ---"

do
    print("Testing...", "await or 1")
    spawn(function ()
        local v = await({tag='or', 'X', 'Y'})
        out(v.tag,v[1])
    end)
    emit { tag='Y', 10 }
    assertx(out(), "Y\t10\n")
    atmos.stop()
end

do
    print("Testing...", "await or 2")
    spawn(function ()
        local v = await {tag='or', {tag='Y',5}, {tag='Y',10}}
        out(v.tag, v[1])
    end)
    emit{tag='Y',10}
    assertx(out(), "Y\t10\n")
    atmos.stop()
end

do
    print("Testing...", "await or 3: task")
    spawn(function ()
        local t = spawn(function ()
            await 'X'
            return 10
        end)
        local v,u = await {tag='or', t, 'X'}
        out(v,u==t)
    end)
    emit 'X'
    assertx(out(), "10\ttrue\n")
    atmos.stop()
end

do
    print("Testing...", "await or 4: tasks")
    spawn(function ()
        local ts = tasks()
        local t = spawn_in(ts, function ()
            return await 'X'
        end)
        local v,u,q = await {tag='or', ts, 'X'}
        out(v=='X',u==t,q==ts)
    end)
    emit 'X'
    assertx(out(), "true\ttrue\ttrue\n")
    atmos.stop()
end

do
    print("Testing...", "await or 5: clock")
    spawn(function ()
        local v,u = await {tag='or', 'X', clock{s=1}}
        out(v,u)
    end)
    emit{tag='clock', ms=510}
    emit{tag='clock', ms=515}
    emit 'X'
    assertx(out(), "clock\t25\n")
    atmos.stop()
end

print "--- AWAIT / _AND_ ---"

do
    print("Testing...", "await and 1")
    spawn(function ()
        local v,u = await({tag='and', 'X', 'Y'})
        out(v.tag, u.tag)
    end)
    emit{tag='Y',10}
    emit{tag='X',20}
    assertx(out(), "X\tY\n")
    atmos.stop()
end

do
    print("Testing...", "await and 2")
    spawn(function ()
        local v,u = await {tag='and', 'Y', 'Y'}
        out(v,u)
    end)
    emit('Y')
    assertx(out(), "Y\tY\n")
    atmos.stop()
end

do
    print("Testing...", "await and 3: task")
    spawn(function ()
        local t = spawn(function ()
            await 'X'
            return 10
        end)
        local v,u = await {tag='and', t, 'X'}
        out(v,u)
    end)
    emit 'X'
    assertx(out(), "10\tX\n")
    atmos.stop()
end

do
    print("Testing...", "await and 4: tasks")
    spawn(function ()
        local ts = tasks()
        local t = spawn_in(ts, function ()
            return await 'X'
        end)
        local v,u = await {tag='and', ts, 'X'}
        out(v=='X', u)
    end)
    emit 'X'
    assertx(out(), "true\tX\n")
    atmos.stop()
end

do
    print("Testing...", "await and 5: clock")
    spawn(function ()
        local v,u = await {tag='and', 'X', clock{s=1}}
        out(v, u)
    end)
    emit{tag='clock', ms=510}
    emit{tag='clock', ms=515}
    emit 'X'
    assertx(out(), "X\tclock\n")
    atmos.stop()
end

print '--- AND / OR ---'

do
    print("Testing...", "await and/or: clock")
    spawn(function ()
        local ts = tasks()
        local t = spawn_in(ts, function ()
            await(false)
        end)
        local T = spawn_in(ts, function ()
            return await('Z')
        end)
        local v,u = await {tag='and', {tag='or', 'X', clock{s=1}}, {tag='or', ts, t}}
        out(v, u=='Z')
    end)
    emit{tag='clock', ms=510}
    emit 'Z'
    emit{tag='clock', ms=515}
    assertx(out(), "clock\ttrue\n")
    atmos.stop()
end

print "--- AWAIT / _NOT_ ---"

do
    print("Testing...", "await not 1")
    spawn(function ()
        local v = await {tag='not', 'X'}
        out(v.tag, v[1])
    end)
    emit{tag='X', 99}
    emit{tag='Y', 10}
    assertx(out(), "Y\t10\n")
    atmos.stop()
end

do
    print("Testing...", "await not 2: in or")
    spawn(function ()
        local v = await {tag='or', {tag='not', 'X'}, 'Y'}
        out(v.tag, v[1])
    end)
    emit 'X'
    emit{tag='Z', 5}
    assertx(out(), "Z\t5\n")
    atmos.stop()
end


