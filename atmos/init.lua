require "atmos.aux"
local run = require "atmos.run"

local atmos = {
    close = run.close
}

throw = run.throw
catch = run.catch

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
    return run.emit(to, e, ...)
end

function emit (e, ...)
    return run.emit(nil, e, ...)
end

await    = run.await
clock    = run.clock
pub      = run.pub
toggle   = run.toggle
every    = run.every
par      = run.par
par_or   = run.par_or
watching = run.watching

return atmos
