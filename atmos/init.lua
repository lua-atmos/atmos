require "atmos.aux"
local run = require "atmos.run"

task = run.task

function spawn_in (up, t, ...)
    return run.spawn(up, t, ...)
end

function spawn (t, ...)
    return run.spawn(nil, t, ...)
end

await = run.await

function emit_in (to, e, ...)
    return run.emit(to, e, ...)
end

function emit (e, ...)
    return run.emit(nil, e, ...)
end
