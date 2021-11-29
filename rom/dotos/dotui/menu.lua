-- .UI menu --

local dotui = require("dotui")
local colors = require("colors")

local window = dotui.window.create(1, 2, 16, 4)
local base = dotui.Menu:new {
  x = 1, y = 1, w = window.w, h = window.h,
  fg = colors.white,
  bg = colors.gray,
}
window:addPage("main", base)

base:addItem("Shut Down", function()
  dotui.util.loadApp(".shutdown", "/dotos/dotui/shutdown.lua")
  window.delete = true
end)

while not window.delete do
  window:draw()
  local sig = window:receiveSignal()
  if sig[1] == "unfocus" then
    window.delete = true
  elseif sig[1] == "mouse_click" then
    local element = window:find(sig[3], sig[4])
    if element then element:callback() end
  end
end

dotos.exit()
