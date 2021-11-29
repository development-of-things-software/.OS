-- .OS Desktop --

local dotui = require("dotui")
local colors = require("colors")
local types = require("sigtypes")

local surface, window = dotui.window.create(1, 1, 1, 1)
window.keepInBackground = true

local base = dotui.UIPage:new {
  x = 1, y = 1, w = surface.w, h = surface.h,
  fg = colors.gray, bg = colors.lightBlue, surface = surface
}

base:addChild(dotui.Label:new {
  x = 1, y = surface.h, w = surface.w, h = 1,
  fg = colors.gray, bg = colors.lightBlue, text = os.version()
})

local menubar = dotui.UIPage:new {
  x = 1, y = 1, w = surface.w, h = 1,
  fg = colors.lightBlue, bg = colors.gray
}

local menu = dotui.UIPage:new {
  x = 1, y = 2,
  w = 16, h = 5,
  bg = colors.gray, fg = colors.lightGray,
}
menu.hidden = true

local menubtn = dotui.Clickable:new {
  x = 1,
  y = 1,
  w = 6, h = 1,
  bg = colors.lightGray, fg = colors.black,
  callback = function()
    menu.hidden = not menu.hidden
  end,
  surface = surface,
  text = " Menu "
}
--[[
menubtn:addChild(dotui.Label:new {
  x = 1, y = 1, w = 6, h = 1, text = " Menu ",
  bg = colors.lightGray, fg = colors.black
})]]

base:addChild(menubar)
menubar:addChild(menubtn)
base:addChild(menu)

-- menu entries
menu:addChild(dotui.Clickable:new {
  x = 1, y = 1, w = 16, h = 1, bg = colors.gray, fg = colors.lightGray,
  text = "Restart", callback = function()
    local res = dotui.util.prompt("Are you sure you want to reboot?",
      {"Yes", "No"})
    if res == "Yes" then
      os.reboot()
    end
  end
})

while true do
  surface:fill(1, 1, surface.w, surface.h, " ", colors.lightBlue,
    colors.lightBlue)
  surface:fill(1, 1, surface.w, 1, " ", colors.lightBlue, colors.gray)
  base:draw()
  local sig = window:receiveSignal()
  if sig[1] == "mouse_click" then
    local element = base:find(sig[3], sig[4])
    if element then
      element:callback()
    end
  end
end
