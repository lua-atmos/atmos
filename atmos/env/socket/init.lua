local atmos = require "atmos"

local socket = require "socket"

local M = {}

local rs = {}
local ss = {}

local function rem (l, v)
    for i,x in ipairs(l) do
        if x == v then
            table.remove(l, i)
            return
        end
    end
    error "bug found"
end

function M.xtcp ()
    local tcp, err = socket.tcp()
    if tcp == nil then
        return nil, err
    end
    tcp:settimeout(0)
    return tcp
end

function M.xlisten (tcp, backlog)
    local ok, err = tcp:listen(baclog)
    if ok == nil then
        return nil, err
    end
    assert(ok == 1)
    local srv = tcp
    srv:settimeout(0)
    rs[#rs+1] = srv
    return 1
end

function M.xaccept (srv)
    await(srv, 'recv')
    local cli, err = srv:accept()
    if cli == nil then
        return nil, err
    end
    cli:settimeout(0)
    return cli
end

function M.xconnect (tcp, addr, port)
    ss[#ss+1] = tcp
    local _ <close> = defer(function ()
        rem(ss, tcp)
    end)
    local ok, err = tcp:connect(addr, port)
    assert(ok==nil and err=='timeout')
    await(tcp, 'send')
--[[
    local ok, err = tcp:connect(addr, port)
    if ok==1 or (ok==nil and err=="Already connected") then
        return 1
    else
        return nil, err
    end
]]
    return tcp:connect(addr, port)
end

function M.xrecv (tcp)
    rs[#rs+1] = tcp
    local _ <close> = defer(function ()
        rem(rs, tcp)
    end)
    local _,_,s = await(tcp, 'recv')
    return s
end

local old

function M.init ()
    old = socket.gettime()
end

function M.step (opts)
    local r,s = socket.select(rs, ss, 0.1)
    for k in pairs(r) do
        if type(k) == 'userdata' then
            local v = ""
            if k:getpeername() then
                local a,b,c,d,e = k:receive('*a')
                v = c
            end
--print('recv', k, v)
            emit(k, 'recv', v)
        end
    end
    for k in pairs(s) do
        if type(k) == 'userdata' then
--print('send', k, v)
            emit(k, 'send')
        end
    end
    if (not opts) or (opts.clock~=false) then
        local now = socket.gettime()
        if now > old then
            emit(clock { ms=(now-old)*1000 })
            old = now
        end
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
