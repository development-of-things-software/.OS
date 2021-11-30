-- .OS Desktop --

local dotui = require("dotui")
local colors = require("colors")
local types = require("sigtypes")

local window = dotui.window.create(1, 1, 1, 1)
window.keepInBackground = true

local base = dotui.UIPage:new {
  x = 1, y = 1, w = window.w, h = window.h,
  fg = colors.gray, bg = colors.lightBlue, surface = window.buffer
}

base:addChild(dotui.Label:new {
  x = 1, y = 0, w = #os.version(), h = 1,
  fg = colors.gray, bg = colors.lightBlue, text = os.version()
})

local menubar = dotui.UIPage:new {
  x = 1, y = 1, w = window.w, h = 1,
  fg = colors.lightBlue, bg = colors.gray
}

local menupid = 0
local menubtn = dotui.Clickable:new {
  x = 1,
  y = 1,
  w = 6, h = 1,
  callback = function()
    if not dotos.running(menupid) then
      menupid = dotui.util.loadApp(".menu", "/dotos/dotui/menu.lua") or 0
    else
      dotos.kill(menupid)
    end
  end,
  text = " Menu "
}

base:addChild(menubar)
menubar:addChild(menubtn)

local surface = window.buffer
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
    else
      dotos.kill(menupid)
    end
  elseif sig[1] == "thread_died" then
    dotui.util.prompt(sig[3], {"OK",
      title = "Thread " .. sig[2] .. " Died"})
  end
end
