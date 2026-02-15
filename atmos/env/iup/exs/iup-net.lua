local atmos = require "atmos"
local env_sok = require "atmos.env.socket"
local env_iup = require "atmos.env.iup"

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

local opts = { clock=false }
atmos.env = {
    open = function ()
        if env_iup.env.open then env_iup.env.open() end
    end,
    step = function ()
        env_sok.step(opts)
        return env_iup.env.step()
    end,
    close = function ()
        env_iup.env.close()
    end,
}

atmos.loop(function ()
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
