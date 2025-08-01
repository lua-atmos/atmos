require "atmos.util"
local run = require "atmos.run"

local atmos = {
    close  = run.close,
    call   = run.call,
    status = run.status,
    env    = run.env,
}

_is_  = run.is
throw = run.throw
catch = run.catch
call  = run.call

defer = run.defer
tasks = run.tasks

function task (inv, ...)
    if inv == nil then
        return run.me()
    elseif type(inv) == 'boolean' then
        return run.task(debug.getinfo(2), inv, ...)
    else
        return run.task(debug.getinfo(2), false, inv, ...)
    end
end

function spawn_in (up, t, ...)
    return run.spawn(debug.getinfo(2), up, false, t, ...)
end

function spawn (inv, t, ...)
    if type(inv) == 'boolean' then
        return run.spawn(debug.getinfo(2), nil, inv, t, ...)
    else
        return run.spawn(debug.getinfo(2), nil, false, inv, t, ...)
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
