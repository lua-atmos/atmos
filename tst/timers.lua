local atmos = require "atmos"
require "test"

print '--- TIMERS ---'

do
    print("Testing...", "timers 1: residual carried")
    spawn(task(function ()
        await(10*_ms_)
        await(10*_ms_)
        out 'ok'
    end))
    emit(25*_ms_)               -- 2nd timer: 15ms late carried
    assertx(out(), "ok\n")
    atmos.stop()
end

do
    print("Testing...", "timers 2: time order in one tick")
    spawn(task(function ()
        par_any(
            function () await(20*_ms_); out 'a' end,
            function () await(10*_ms_); out 'b' end
        )
    end))
    emit(30*_ms_)               -- b expires first (10ms)
    assertx(out(), "b\n")
    atmos.stop()
end

do
    print("Testing...", "timers 3: periodic catch-up")
    spawn(task(function ()
        for i=1, 3 do
            await(10*_ms_)
            out(i)
        end
    end))
    emit(35*_ms_)               -- 3 periods in one tick
    assertx(out(), "1\n2\n3\n")
    atmos.stop()
end

do
    print("Testing...", "timers 4: late returned")
    spawn(task(function ()
        out(await(10*_ms_))
        out(await(10*_ms_))
    end))
    emit(25*_ms_)               -- late: 15ms, then 5ms
    assertx(out(), "15000\n5000\n")
    atmos.stop()
end

do
    print("Testing...", "timers 5: clock pieces")
    spawn(task(function ()
        await(10*_ms_)
    end))
    spawn(task(function ()
        for i=1, 2 do
            out(await('clock'))
        end
    end))
    emit(25*_ms_)               -- pieces: 10ms (timer), 15ms (rest)
    assertx(out(), "10000\t15000\n15000\t0\n")
    atmos.stop()
end

do
    print("Testing...", "timers 6: timer born mid-tick")
    spawn(task(function ()
        await(10*_ms_)
        spawn(task(function ()
            await(10*_ms_)      -- born at 10ms: expires at 20ms
            out 'B'
        end))
        await(false)
    end))
    emit(25*_ms_)
    assertx(out(), "B\n")
    atmos.stop()
end

do
    print("Testing...", "timers 7: toggle freezes timer")
    local t = spawn(task(function ()
        await(10*_ms_)
        out 'ok'
    end))
    emit(5*_ms_)                -- 5ms of 10ms
    toggle(t, false)
    emit(20*_ms_)               -- frozen: no time passes for t
    toggle(t, true)
    out '-'
    emit(5*_ms_)                -- 10ms: expires
    assertx(out(), "-\nok\n")
    atmos.stop()
end

do
    print("Testing...", "timers 8: toggle on re-reports timer")
    spawn(task(function () await(20*_ms_); out 'b' end))
    local t = spawn(task(function () await(10*_ms_); out 'a' end))
    toggle(t, false)
    emit(1*_ms_)                -- t frozen: its timer not re-reported
    toggle(t, true)
    emit(30*_ms_)               -- a (10ms) before b (19ms)
    assertx(out(), "a\nb\n")
    atmos.stop()
end
