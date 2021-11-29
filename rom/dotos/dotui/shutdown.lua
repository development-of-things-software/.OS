-- shutdown prompt --

local dotui = require("dotui")
local colors = require("colors")

local window, base = dotui.util.basicWindow(3, 3, 24, 10, "Shutdown")

base.text = "Choose an action to perform:"

local items = {
  "Shut Down",
  "Restart"
}

base:addChild( dotui.Selector:new {
  x = 2, y = 3, w = window.w, h = #items,
  items = items, fg = colors.black, bg = colors.white,
  exclusive = true
} )

dotui.util.genericWindowLoop(window)

dotos.exit()
