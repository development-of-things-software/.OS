local ui = require("dotui.ui")
local surface = require("dotui.surface")

local callbacks = {
  menu = function()
  end
}

local desktop = ui.load("/dotos/dotui/desktop.ui", callbacks)

desktop.page = "main"
surface.register(desktop.surface)
ui.loop(desktop)
