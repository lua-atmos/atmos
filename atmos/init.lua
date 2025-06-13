require "atmos.aux"
local run = require "atmos.run"

local atmos = {
    close = run.close
}

defer = run.defer
tasks = run.tasks
task  = run.task

function spawn_in (up, t, ...)
    return run.spawn(up, t, ...)
end

function spawn (t, ...)
    return run.spawn(nil, t, ...)
end

await = run.await
clock = run.clock

function emit_in (to, e, ...)
    return run.emit(to, e, ...)
end

function emit (e, ...)
    return run.emit(nil, e, ...)
end

pub = run.pub

every = run.every
par = run.par
watching = run.watching

return atmos
