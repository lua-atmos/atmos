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
    --
    thread_modules = run.thread_modules,
}

loop  = run.loop
start = run.start
stop  = run.stop

_is_    = run.is
_break_ = run._break_
throw   = run.throw
catch   = run.catch
defer   = run.defer
tasks   = run.tasks
abort   = run.abort

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

function emit_in (to, emt, ...)
    return run.emit(true, to, emt, ...)
end

function emit (emt, ...)
    assertn(2, emt~=nil and select('#',...)==0,
        "invalid emit : invalid event"
    )
    return run.emit(true, nil, emt, ...)
end

function await (awt, ...)
    assertn(2, awt~=nil and select('#',...)==0,
        "invalid await : invalid event pattern"
    )
    return run.await(awt)
end

clock    = run.clock

toggle   = run.toggle
thread   = run.thread

every    = run.every
par      = run.par
par_or   = run.par_or
par_and  = run.par_and
watching = run.watching

return atmos
