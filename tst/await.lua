local atmos = require "atmos"
require "test"

print "--- AWAIT / _OR_ ---"

do
    print("Testing...", "await or 1")
    spawn_task(task(function ()
        local v = await({tag='or', 'X', 'Y'})
        out(v.tag,v[1])
    end))
    emit { tag='Y', 10 }
    assertx(out(), "Y\t10\n")
    atmos.stop()
end

do
    print("Testing...", "await or 2")
    spawn_task(task(function ()
        local v = await {tag='or', {tag='Y',5}, {tag='Y',10}}
        out(v.tag, v[1])
    end))
    emit{tag='Y',10}
    assertx(out(), "Y\t10\n")
    atmos.stop()
end

do
    print("Testing...", "await or 3: task")
    spawn_task(task(function ()
        local t = spawn_task(task(function ()
            await 'X'
            return 10
        end))
        local v,u = await {tag='or', t, 'X'}
        out(v,u==t)
    end))
    emit 'X'
    assertx(out(), "10\ttrue\n")
    atmos.stop()
end

do
    print("Testing...", "await or 4: tasks")
    spawn_task(task(function ()
        local ts = tasks()
        local t = spawn_in(ts, task(function ()
            return await 'X'
        end))
        local v,u,q = await {tag='or', {tag='tasks', mode='any', tasks=ts}, 'X'}
        out(v=='X',u==t,q==ts)
    end))
    emit 'X'
    assertx(out(), "true\ttrue\ttrue\n")
    atmos.stop()
end

do
    print("Testing...", "await or 5: clock")
    spawn_task(task(function ()
        local v = await {tag='or', 'X', 1*_s_}
        out(v)
    end))
    emit(510*_ms_)
    emit(515*_ms_)
    emit 'X'
    assertx(out(), "25000\n")
    atmos.stop()
end

print "--- AWAIT / _AND_ ---"

do
    print("Testing...", "await and 1")
    spawn_task(task(function ()
        local v,u = await({tag='and', 'X', 'Y'})
        out(v.tag, u.tag)
    end))
    emit{tag='Y',10}
    emit{tag='X',20}
    assertx(out(), "X\tY\n")
    atmos.stop()
end

do
    print("Testing...", "await and 2")
    spawn_task(task(function ()
        local v,u = await {tag='and', 'Y', 'Y'}
        out(v,u)
    end))
    emit('Y')
    assertx(out(), "Y\tY\n")
    atmos.stop()
end

do
    print("Testing...", "await and 3: task")
    spawn_task(task(function ()
        local t = spawn_task(task(function ()
            await 'X'
            return 10
        end))
        local v,u = await {tag='and', t, 'X'}
        out(v,u)
    end))
    emit 'X'
    assertx(out(), "10\tX\n")
    atmos.stop()
end

do
    print("Testing...", "await and 4: tasks")
    spawn_task(task(function ()
        local ts = tasks()
        local t = spawn_in(ts, task(function ()
            return await 'X'
        end))
        local v,u = await {tag='and', {tag='tasks', mode='any', tasks=ts}, 'X'}
        out(v=='X', u)
    end))
    emit 'X'
    assertx(out(), "true\tX\n")
    atmos.stop()
end

do
    print("Testing...", "await and 5: clock")
    spawn_task(task(function ()
        local v,u = await {tag='and', 'X', 1*_s_}
        out(v, u)
    end))
    emit(510*_ms_)
    emit(515*_ms_)
    emit 'X'
    assertx(out(), "X\t25000\n")
    atmos.stop()
end

print '--- AND / OR ---'

do
    print("Testing...", "await and/or: clock")
    spawn_task(task(function ()
        local ts = tasks()
        local t = spawn_in(ts, task(function ()
            await(false)
        end))
        local T = spawn_in(ts, task(function ()
            return await('Z')
        end))
        local v,u = await {tag='and', {tag='or', 'X', 1*_s_}, {tag='or', {tag='tasks', mode='any', tasks=ts}, t}}
        out(v, u=='Z')
    end))
    emit(510*_ms_)
    emit 'Z'
    emit(515*_ms_)
    assertx(out(), "25000\ttrue\n")
    atmos.stop()
end

print "--- AWAIT / _NOT_ ---"

do
    print("Testing...", "await not 1")
    spawn_task(task(function ()
        local v = await {tag='not', 'X'}
        out(v.tag, v[1])
    end))
    emit{tag='X', 99}
    emit{tag='Y', 10}
    assertx(out(), "Y\t10\n")
    atmos.stop()
end

do
    print("Testing...", "await not 2: in or")
    spawn_task(task(function ()
        local v = await {tag='or', {tag='not', 'X'}, 'Y'}
        out(v.tag, v[1])
    end))
    emit 'X'
    emit{tag='Z', 5}
    assertx(out(), "Z\t5\n")
    atmos.stop()
end

do
    print("Testing...", "await not 3: nested emit must not shadow outer")
    spawn_task(task(function ()
        await 'X'
        emit_in('global', 'Y')
        await(false)
    end))
    spawn_task(task(function ()
        local v = await {tag='not', 'Y'}
        out(v.tag, v[1])
    end))
    emit{tag='X', 7}
    assertx(out(), "X\t7\n")
    atmos.stop()
end

print "--- AWAIT / _UNTIL_ ---"

do
    print("Testing...", "await while 1: pred false -> event")
    spawn_task(task(function ()
        local v = await {tag='while', 'X', function (e) return e[1]~=10 end}
        out(v.tag, v[1])
    end))
    emit{tag='X', 10}
    assertx(out(), "X\t10\n")
    atmos.stop()
end

do
    print("Testing...", "await while 2: pred true -> re-await next")
    spawn_task(task(function ()
        local v = await {tag='while', 'X', function (e) return e[1]~=10 end}
        out(v[1])
    end))
    emit{tag='X', 5}
    emit{tag='X', 10}
    assertx(out(), "10\n")
    atmos.stop()
end

do
    print("Testing...", "await until 3: many preds, all hold")
    spawn_task(task(function ()
        local v = await {tag='until', 'X',
            function (e) return e[1]>0 end,
            function (e) return e[1]<100 end
        }
        out(v[1])
    end))
    emit{tag='X', 50}
    assertx(out(), "50\n")
    atmos.stop()
end

do
    print("Testing...", "await until 4: many preds, one false")
    spawn_task(task(function ()
        local v = await {tag='until', 'X',
            function (e) return e[1]>0 end,
            function (e) return e[1]<100 end
        }
        out(v[1])
    end))
    emit{tag='X', 200}
    emit{tag='X', 50}
    assertx(out(), "50\n")
    atmos.stop()
end

do
    print("Testing...", "await while 5: over or (full matching reused)")
    spawn_task(task(function ()
        local v = await {tag='while', {tag='or', 'X', 'Y'},
            function (e) return e[1]~=9 end
        }
        out(v.tag, v[1])
    end))
    emit{tag='X', 1}
    emit{tag='Y', 9}
    assertx(out(), "Y\t9\n")
    atmos.stop()
end

do
    print("Testing...", "await until 6: pred returns x -> result is x")
    spawn_task(task(function ()
        local v = await {tag='until', 'X', function (e) return e[1]*2 end}
        out(v)
    end))
    emit{tag='X', 21}
    assertx(out(), "42\n")
    atmos.stop()
end

do
    print("Testing...", "await until 7: last pred decides result")
    spawn_task(task(function ()
        local v = await {tag='until', 'X',
            function (e) return e[1]>0 end,
            function (e) return e[1]*2 end
        }
        out(v)
    end))
    emit{tag='X', 21}
    assertx(out(), "42\n")
    atmos.stop()
end

do
    print("Testing...", "await until 8: error: no predicate")
    local _,err = pcall(function ()
        spawn_task(task(function ()
            await {tag='until', 'X'}
        end))
    end)
    assertfx(err, "await.lua:300: invalid await : expected predicate")
    atmos.stop()
end

do
    print("Testing...", "await until 9: nested emit must not shadow outer")
    spawn_task(task(function ()
        await 'X'
        emit_in('global', {tag='X', 2})
    end))
    spawn_task(task(function ()
        local v = await {tag='until', 'X', function (e) return e[1]==1 end}
        out(v[1])
    end))
    emit{tag='X', 1}
    assertx(out(), "1\n")
    atmos.stop()
end

print "--- AWAIT / CLOCK ---"

-- basic: wakes on the next numeric emit, returns the delta
do
    print("Testing...", "await clock 1")
    spawn_task(task(function ()
        local v = await('clock')
        out(v)
    end))
    emit(510*_ms_)
    assertx(out(), "510000\n")
    atmos.stop()
end

-- ignores non-numbers: a string emit (even 'clock') does NOT match
do
    print("Testing...", "await clock 2: ignores non-number")
    spawn_task(task(function ()
        local v = await('clock')
        out(v)
    end))
    emit('X')
    emit('clock')
    emit(7*_us_)
    assertx(out(), "7\n")
    atmos.stop()
end

-- every('clock'): per-tick deltas accumulate
do
    print("Testing...", "every clock")
    spawn_task(task(function ()
        local n = 0
        every('clock', function (us)
            n = n + us
            if n >= 30 then
                _break_()
            end
        end)
        out(n)
    end))
    emit(10)
    emit(10)
    emit(10)
    assertx(out(), "30\n")
    atmos.stop()
end
