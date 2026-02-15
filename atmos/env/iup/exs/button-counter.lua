require "atmos.env.iup"
require "iuplua"

xtxt = iup.text { value=0, readonly="YES", size="60" }
xbut = iup.button { title="Count", size="60" }
xdlg = iup.dialog {
    title  = "Button - Counter",
    margin = "10x10", 
    iup.hbox {
        xtxt, xbut,
        ngap = "10",
    },
}

xdlg:showxy(iup.CENTER, iup.CENTER)

loop(function ()
    every(xbut,'action', function ()
        xtxt.value = xtxt.value + 1
    end)
end)
