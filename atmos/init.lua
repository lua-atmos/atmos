require "atmos.aux"
local run = require "atmos.run"

local atmos = {
    close = run.close
}

me    = run.me
throw = run.throw
catch = run.catch
call  = run.call

defer = run.defer
tasks = run.tasks
task  = run.task

function spawn_in (up, t, ...)
    return run.spawn(up, false, t, ...)
end

function spawn (nested, t, ...)
    if type(nested) == 'boolean' then
        return run.spawn(nil, nested, t, ...)
    else
        return run.spawn(nil, false, nested, t, ...)
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
toggle   = run.toggle
every    = run.every
par      = run.par
par_or   = run.par_or
watching = run.watching

return atmos
