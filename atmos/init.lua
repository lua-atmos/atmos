require "atmos.util"
local run = require "atmos.run"
local X = require "atmos.x"

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

_break_ = run._break_
throw   = run.throw
catch   = run.catch
defer   = run.defer
tasks   = run.tasks
abort   = run.abort

function task (f)
    return run.task(debug.getinfo(2), f)
end

function xtask (T)
    if T == nil then
        return run.me()
    else
        return run.xtask(debug.getinfo(2), false, T)
    end
end

function spawn_in (up, t, ...)
    return run.spawn(debug.getinfo(2), up, false, t, ...)
end

function spawn (t, ...)
    return run.spawn(debug.getinfo(2), nil, false, t, ...)
end

-- a transparent task has no identity to manipulate, so we return a
-- close-only handle instead of the instance: it carries `__close` (to
-- bind the body to a lexical block via `<close>`) and hides the xtask.
-- `t` is kept in the closure, inaccessible from the handle.
function do_spawn (f, ...)
    local t = run.spawn(debug.getinfo(2), nil, true, f, ...)
    return setmetatable({}, {
        __close = function ()
            getmetatable(t).__close(t)
        end
    })
end

function emit_in (to, emt, ...)
    return run.emit(true, to, emt, ...)
end

function emit (emt, ...)
    assertn(2, select('#',...) == 0,
        "invalid emit : invalid event"
    )
    return run.emit(true, nil, emt, ...)
end

function await (awt, ...)
    if X.is(awt, 'task') then
        -- await T(...)
        return await(run.spawn(debug.getinfo(2), nil, false, awt, ...))
    elseif type(awt) == 'function' then
        -- await f(...)
        assertn(2, false, "invalid spawn : expected task prototype")
    else
        -- await(...)
        return run.await(run.TIME, awt, ...)
    end
end

-- clock duration constants (base unit = microseconds)
_us_  = 1
_ms_  = 1000 * _us_
_s_   = 1000 * _ms_
_min_ = 60 * _s_
_h_   = 60 * _min_
_day_ = 24 * _h_

toggle   = run.toggle
thread   = run.thread

loop_on  = run.loop_on
par      = run.par
par_any  = run.par_any
par_all  = run.par_all
watching = run.watching

return atmos
