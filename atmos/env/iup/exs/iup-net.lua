local atmos = require "atmos"
local env_sok = require "atmos.env.socket"
local env_iup = require "atmos.env.iup"

package.cpath = package.cpath .. ';/usr/lib64/libiuplua54.so'
require("iuplua")

counter = 0

function addCount()
	counter = counter + 1
end

function getCount()
	return counter
end

--********************************** Main *****************************************

txt_count = iup.text{value = getCount(), readonly = "YES",  size = "60"}
btn_count = iup.button{title = "Count", size = "60"}

dlg = iup.dialog{iup.hbox{txt_count, btn_count; ngap = "10"}, title = "Counter", margin = "10x10"}

dlg:showxy( iup.CENTER, iup.CENTER )

local env = {
    init = function (on)
        env_sok.init(on)
        env_iup.init(on)
    end,
    loop = env_iup.loop,
}
    
local opts = { clock=false }
iup.SetIdle(function ()
    env_sok.step(opts)
end)

atmos.call(env, function ()
    spawn(function ()
        every(clock{s=1}, function ()
            print'1s'
        end)
    end)
    every(btn_count,'action', function ()
        addCount()
        txt_count.value = getCount()
    end)
end)
