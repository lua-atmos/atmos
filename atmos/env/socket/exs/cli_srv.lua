require "atmos.env.socket"

local socket = require "socket"

local srv = assert(socket.tcp())
assert(srv:bind("*", 0))
srv:listen()
local _,p = srv:getsockname()

call(function ()
    par_or(function ()
        await(srv, 'recv')
        local con = assert(srv:accept())
        every(con,'recv', function (_,_,v)
            print('xxx', v)
        end)
    end, function ()
        local cli = assert(socket.tcp())
        local _,err = cli:connect("localhost", p)
        assert(err == 'timeout')
        await(cli, 'send')
        cli:send("oi")
        await(clock{s=1})
        cli:send("123\n")
        await(clock{s=1})
    end)
end)
