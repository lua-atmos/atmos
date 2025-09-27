require "atmos.env.clock"
local S = require "atmos.streams"

call(function ()

    -- Tasks & Events

    -- 1.1
    print "-=-=- 1.1 -=-=-"
    function T ()
        await(false)
    end
    local t1 = spawn(T)    -- starts `t1`
    local t2 = spawn(T)    -- starts `t2`
    print(t1, t2)          -- t1 & t2 started and are now suspended

    -- 1.2
    print "-=-=- 1.2 -=-=-"
    function T (i)
        await('X')
        print("task " .. i .. " awakes from X")
    end
    spawn(T, 1)
    spawn(T, 2)
    emit('X')
        -- "task 1 awakes from X"
        -- "task 2 awakes from X"

    -- Scheduling & Hierarchy

    -- 2.1
    print "-=-=- 2.1 -=-=-"
    print "1"
    spawn(function ()
        print "a1"
        await 'X'
        print "a2"
    end)
    print "2"
    spawn(function ()
        print "b1"
        await 'X'
        print "b2"
    end)
    print "3"
    emit 'X'
    print "4"

    -- 2.2
    print "-=-=- 2.2 -=-=-"
    spawn(function ()
        spawn(function ()
            await 'Y'   -- never awakes after 'X' occurs
            print "never prints"
        end)
        await 'X'       -- aborts the whole task hierarchy
        print "awakes from X"
    end)
    emit 'X'
    emit 'Y'

    -- 3.1
    print "-=-=- 3.1 -=-=-"
    spawn(function ()
        await "X"       -- awakes when "x" emits "X"
        print("terminates after X")
    end)
    emit "X"

    -- 3.2
    print "-=-=- 3.2 -=-=-"
    print("Counts 5 seconds:")
    for i=1,5 do
        await(clock{ms=100})
        print("1 second...")
    end
    print("5 seconds elapsed.")

    -- 4.1
    spawn(function ()
        S.fr_awaits('X')
            :filter(function(x) return x.v%2 == 1 end)
            :map(function(x) return x.v end)
            :tap(print)
            :to()
    end)
    for i=1, 10 do
        await(clock{s=1})
        emit { tag='X', v=i }
    end
end)
