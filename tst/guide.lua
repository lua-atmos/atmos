require "atmos.env.clock"
local S = require "atmos.streams"

loop(function ()

    -- 1. Tasks & Events

    -- 1.1
    do
        print "-=-=- 1.1 -=-=-"
        local T = task(function ()
            await(false)
        end)
        local t1 = spawn(T)         -- starts `t1`
        local t2 = spawn(T)         -- starts `t2`
        print(t1, t2)               -- t1 & t2 started and are now suspended
    end

    -- 1.2
    do
        print "-=-=- 1.2 -=-=-"
        local T = task(function (i)
            await('X')
            print("task " .. i .. " awakes on X")
        end)
        spawn(T, 1)
        spawn(T, 2)
        emit('X')
            -- "task 1 awakes on X"
            -- "task 2 awakes on X"
    end

    -- 1.3
    do
        print "-=-=- 1.3 -=-=-"
        do_spawn(function()
            await('X')
            print("anon task awakes on X")
        end)
        emit('X')
            -- "anon task awakes on X"
    end

    -- 2. External Environments

    -- 2.1
    do
        print "-=-=- 2.1 -=-=-"
        do_spawn(function ()
            await "X"       -- awakes when "x" emits "X"
            print("terminates after X")
        end)
        emit "X"
    end

    -- 2.2
    do
        print "-=-=- 2.2 -=-=-"
        print("Counts 5 seconds:")
        for i=1,5 do
            await(100*_ms_)
            print("1 second...")
        end
        print("5 seconds elapsed.")
    end

    -- 3. Lexical Structure

    -- 3.1
    do
        print "-=-=- 3.1 -=-=-"
        print "1"
        do_spawn(function ()
            print "a1"
            await 'X'
            print "a2"
        end)
        print "2"
        do_spawn(function ()
            print "b1"
            await 'X'
            print "b2"
        end)
        print "3"
        emit 'X'
        print "4"
    end

    -- 3.2
    do
        print "-=-=- 3.2 -=-=-"
        do_spawn(function ()
            do_spawn(function ()
                await 'Y'   -- never awakes after 'X' occurs
                print "never prints"
            end)
            await 'X'       -- awakes and aborts the whole task hierarchy
            print "awakes from X"
        end)
        emit 'X'
        emit 'Y'
    end

    -- 3.3
    do
        print "-=-=- 3.3 -=-=-"
        do_spawn(function ()
            do_spawn(function ()
                local _ <close> = defer(function ()
                    print "nested task aborted"
                end)
                await(false) -- never awakes
            end)
            -- will abort nested task
        end)
    end

    -- 3.4
    do
        print "-=-=- 3.4 -=-=-"
        print '1'
        do
            local _ <close> = do_spawn(function ()
                local _ <close> = defer(function ()
                    print 'x'
                end)
                await(false)
            end)
            local _ <close> = defer(function ()
                print 'y'
            end)
        end
        print '2'
        -- 1, y, x, 2
    end

    -- 4. Compound Statements

    -- 4.1
    do
        print "-=-=- 4.1 -=-=-"
        watching(1*_s_, function()
            loop_on(100*_ms_, function ()
                print "100 ms elapses"    -- prints this message every second
            end)
        end)
    end

    -- 4.2
    do
        print "-=-=- 4.2 -=-=-"
        do_spawn(function()
            watching(1*_s_, function ()
                await 'X'
                print "X happens before 1s" -- prints this message unless 1 second elapses
            end)
        end)
        emit 'X'
    end

    -- 4.3
    do
        print "-=-=- 4.3 -=-=-"
        do_spawn(function()
            par_and(function ()
                await 'X'
            end, function ()
                await 'Y'
            end, function ()
                await 'Z'
            end)
            print "X, Y, and Z occurred"
        end)
        emit 'X'
        emit 'Z'
        emit 'Y'
    end

    -- 5. More about Tasks

    -- 5.1
    do
        print "-=-=- 5.1 -=-=-"
        local T = task(function ()
            xtask().v = 10
        end)
        local t = spawn(T)
        print(t.v)  -- 10
    end

    -- 5.2
    do
        print "-=-=- 5.2 -=-=-"
        local T = task(function (id, ms)
            xtask().id = id
            print('start', id, ms)
            await(ms*_ms_)
            print('stop', id, ms)
        end)
        do
            local ts <close> = tasks()
            for i=1, 10 do
                spawn_in(ts, T, i, math.random(500,1500))
            end
            await(1*_s_)
            for _,t in pairs(ts) do
                print(t.id)
            end
        end
    end

    -- 5.3
    do
        print "-=-=- 5.3 -=-=-"
        local t = spawn(task(function ()
            await 'X'
            print "awakes from X"
        end))
        toggle(t, false)
        emit 'X'    -- ignored
        toggle(t, true)
        emit 'X'    -- awakes
    end

    -- 5.4
    do
        print "-=-=- 5.4 -=-=-"
        local _ <close> = do_spawn(function()
            toggle('X', function ()
                loop_on(100*_ms_, function ()
                    print "100ms elapses"
                end)
            end)
        end)
        print 'off'
        emit{tag='X', false}    -- body above toggles off
        await(1*_s_)
        print 'on'
        emit{tag='X', true}     -- body above toggles on
        await(1*_s_)
    end

    -- 7. Functional Streams

    -- 7.1
    do
        print "-=-=- 7.1 -=-=-"
        local _ <close> = do_spawn(function ()
            S.fr_await('X')
                :filter(function(x) return x.v%2 == 1 end)
                :map(function(x) return x.v end)
                :tap(print)
                :to()
        end)
        for i=1, 10 do
            await(1*_ms_)
            emit { tag='X', v=i }
        end
    end

    -- 7.2
    do
        print "-=-=- 7.2 -=-=-"
        function T ()
            await('X')
            await('Y')
        end
        local _ <close> = do_spawn(function ()
            S.fr_await(T)                           -- XY, XY, ...
                :zip(S.from(1))                     -- {XY,1}, {XY,2} , ...
                :map(function (t) return t[2] end)  -- 1, 2, ...
                :take(2)                            -- 1, 2
                :tap(print)
                :to()
        end)
        emit('X')
        emit('X')
        emit('Y')   -- 1
        emit('X')
        emit('Y')   -- 2
        emit('Y')
    end

end)
