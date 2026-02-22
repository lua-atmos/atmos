require "atmos.util"
local run = require "atmos.run"

local atmos = {
    loop   = run.loop,
    --
    start  = run.start,
    stop   = run.stop,
    --
    status = run.status,
    env    = run.env,
}

loop  = run.loop
start = run.start
stop  = run.stop

_is_  = run.is
throw = run.throw
catch = run.catch
defer = run.defer
tasks = run.tasks

function task (tra, ...)
    if tra == nil then
        return run.me()
    elseif type(tra) == 'boolean' then
        return run.task(debug.getinfo(2), tra, ...)
    else
        return run.task(debug.getinfo(2), false, tra, ...)
    end
end

function spawn_in (up, t, ...)
    return run.spawn(debug.getinfo(2), up, false, t, ...)
end

function spawn (tra, t, ...)
    if type(tra) == 'boolean' then
        return run.spawn(debug.getinfo(2), nil, tra, t, ...)
    else
        return run.spawn(debug.getinfo(2), nil, false, tra, t, ...)
    end
end

function emit_in (to, e, ...)
    return run.emit(true, to, e, ...)
end

function emit (e, ...)
    return run.emit(true, nil, e, ...)
end

await    = run.await
clock    = run.clock
_or_     = run._or_
_and_    = run._and_
toggle   = run.toggle
every    = run.every
par      = run.par
par_or   = run.par_or
par_and  = run.par_and
watching = run.watching

return atmos
