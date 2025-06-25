require "atmos.aux"
local run = require "atmos.run"

local atmos = {
    close = run.close
}

me    = run.me
throw = run.throw
catch = run.catch
loop  = run.loop
step  = run.step

defer = run.defer
tasks = run.tasks

function task (...)
    return run.task(1, ...)
end

function spawn_in (up, t, ...)
    return run.spawn(1, up, false, t, ...)
end

function spawn (nested, t, ...)
    if type(nested) == 'boolean' then
        return run.spawn(1, nil, nested, t, ...)
    else
        return run.spawn(1, nil, false, nested, t, ...)
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
