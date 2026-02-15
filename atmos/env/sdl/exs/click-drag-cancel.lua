require "atmos"
local x = require "atmos.x"
local sdl = require "atmos.env.sdl"
local SDL = require "SDL"
local TTF = require "SDL.ttf"

local point_vs_rect = sdl.point_vs_rect

_,REN = sdl.window {
	title  = "Lua-Atmos-SDL: Click, Drag, Cancel",
	width  = 256,
	height = 256,
    flags  = { SDL.flags.OpenGL },
}

FNT = assert(TTF.open("DejaVuSans.ttf", 20))

loop(function ()
    local text = " "
    local rect = {x=256/2-20,y=256/2-20, w=40,h=40}
    spawn(function ()
        every('sdl.draw', function ()
            REN:setDrawColor(0x000000)
            REN:clear()
            REN:setDrawColor(0xFFFFFF)
            REN:fillRect(sdl.ints(rect))
            sdl.write(FNT, text, {x=256/2, y=200})
            REN:present()
        end)
    end)
    while true do
        local click = await(SDL.event.MouseButtonDown, function (e)
            return point_vs_rect(e, rect), e
        end)
        local orig = x.copy(rect)
        text = "... clicking ..."
        par_or(function ()
            await(SDL.event.KeyDown, 'Escape')
            rect = orig
            text = "!!! CANCELLED !!!"
        end, function ()
            par_or(function ()
                await(SDL.event.MouseMotion)
                text = "... dragging ..."
                await(SDL.event.MouseButtonUp)
                text = "!!! DRAGGED !!!"
            end, function ()
                every(SDL.event.MouseMotion, function (e)
                    rect.x = orig.x + (e.x - click.x)
                    rect.y = orig.y + (e.y - click.y)
                end)
            end)
        end, function ()
            await(SDL.event.MouseButtonUp)
            text = "!!! CLICKED !!!"
        end)
    end
end)
