require "atmos"
local x = require "atmos.x"
local env  = require "atmos.env.pico"
local pico = require "pico"

pico.set.title "Lua-Atmos-SDL: Click, Drag, Cancel"
pico.set.size.window(256, 256)
pico.set.font(nil, 20)

loop(function ()
    local text = ""
    local rect = {x=256/2,y=256/2, w=40,h=40}
    spawn(function ()
        local pt = {x=256/2, y=220}
        every('draw', function ()
            pico.output.draw.rect(rect)
            pico.output.draw.text(pt, text)
        end)
    end)
    while true do
        local click = await('mouse.button.dn', function (e)
            return pico.vs.pos_rect(e, rect), e
        end)
        local orig = x.copy(rect)
        text = "... clicking ..."
        par_or(function ()
            await('key.dn', 'Escape')
            rect = orig
            text = "!!! CANCELLED !!!"
        end, function ()
            par_or(function ()
                await 'mouse.motion'
                text = "... dragging ..."
                await 'mouse.button.up'
                text = "!!! DRAGGED !!!"
            end, function ()
                every('mouse.motion', function (e)
                    rect.x = orig.x + (e.x - click.x)
                    rect.y = orig.y + (e.y - click.y)
                end)
            end)
        end, function ()
            await 'mouse.button.up'
            text = "!!! CLICKED !!!"
        end)
    end
end)
