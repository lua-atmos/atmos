require "atmos"
local env = require "atmos.env.sdl"
local SDL = require "SDL"

local PP  = env.pct_to_pos

_,REN = env.window {
	title  = "Lua-Atmos-SDL: Across",
	width  = 100,
	height = 100,
}

local pt1 = PP(0,0)
local pt2 = PP(100,100)

local dy = (pt2.y - pt1.y) / (pt2.x - pt1.x)

for i=pt1.x, pt2.x do
    REN:setDrawColor(0x000000)
    REN:clear()
    REN:setDrawColor(0xFFFFFF)
    REN:drawPoint { x=i, y=i*dy }
    REN:present()
    SDL.delay(100)
end
