local atmos = require "atmos"

local socket = require "socket"

local l = {}

local socket_tcp = socket.tcp
function socket.tcp (...)
    return (function (s1, ...)
        if s1 then
            s1:settimeout(0)
            local f1 = s1.listen
            local m1 = debug.getmetatable(s1).__index
            m1.listen = function (...)
                return (function (...)
                    local f2 = s1.accept
                    local m2 = debug.getmetatable(s1).__index
                    m2.accept = function (...)
                        return (function (s3, ...)
                            if s3 then
                                s3:settimeout(0)
                                l[#l+1] = s3
                            end
                            return s3, ...
                        end)(f2(...))
                    end
                    return ...
                end)(f1(...))
            end
        end
        l[#l+1] = s1
        return s1, ...
    end)(socket_tcp(...))
end

local M = {}

local old

function M.init ()
    old = socket.gettime()
end

function M.step ()
    local r,s = socket.select(l, l, 0.1)
    for k in pairs(r) do
        if type(k) == 'userdata' then
            local v = ""
            if k:getpeername() then
                local a,b,c,d,e = k:receive('*a')
                v = c
            end
            emit(k, 'recv', v)
        end
    end
    for k in pairs(s) do
        if type(k) == 'userdata' then
            emit(k, 'send')
        end
    end
    local now = socket.gettime()
    if now > old then
        emit(clock { ms=(now-old)*1000 })
        old = now
    end
end

M.env = {
    init = M.init,
    step = M.step,
}

function M.call (body)
    return atmos.call(M.env, body)
end

call = M.call

return M
