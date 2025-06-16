local SDL = require "SDL"
local TTF = require "SDL.ttf"
require "atmos"
local env = require "atmos.env.sdl"

local _ <close> = defer(function ()
    TTF.quit()
    SDL.quit()
end)

WIN = assert(SDL.createWindow, {
	title  = "Lua-Atmos-SDL: Click, Drag, Cancel",
	width  = 256,
	height = 256,
    flags  = @{ SDL.flags.OpenGL },
})
REN = try_sdl(SDL.createRenderer, WIN, -1)

assert(TTF.init())
FNT = assert(TTF.open("DejaVuSans.ttf", 10))

func write (t, str) {
    val sfc = FNT::renderUtf8(str, "blended", @{r=255,g=255,b=255}) -> assert
    val tex = REN::createTextureFromSurface(sfc) -> assert
    set t.str = str
    set t.tex = tex
}

spawn(function ()
    local text = @{ str=" ", tex=nil }
    env.write(FNT, " "
    var rect = @{x=108,y=108, w=40,h=40}
    spawn {
        every :Pico.Draw {
            REN::setDrawColor(0x000000)
            REN::clear()
            REN::setDrawColor(0xFFFFFF)
            REN::fillRect(rect)
            REN::copy(text.tex,nil, @{x=100,y=200,w=100,h=20})
            REN::present()
        }
    }
    loop {
        val click = await(:Pico.Mouse.Button.Dn, rect_vs_pos(rect,evt))
        val orig = copy(rect)
        text->write "... clicking ..."
        par_or {
            await(:Pico.Key.Dn, evt.name==:Escape)
            set rect = copy(orig)
            text->write "!!! CANCELLED !!!"
        } with {
            par_or {
                await(:Pico.Mouse.Motion)
                text->write "... dragging ..."
                await(:Pico.Mouse.Button.Up)
                text->write "!!! DRAGGED !!!"
            } with {
                every :Pico.Mouse.Motion {
                    set rect.x = orig.x + (evt.x - click.x)
                    set rect.y = orig.y + (evt.y - click.y)
                }
            }
        } with {
            await(:Pico.Mouse.Button.Up)
            text->write "!!! CLICKED !!!"
        }
    }
end)

env.loop()
