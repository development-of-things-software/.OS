-- view system logs --

local dotui = require("dotui")
local colors = require("colors")

local window, base = dotui.util.basicWindow(2, 2, 40, 14, "System Logs")

local logs = dotos.getlogs()
local logtext = dotui.Label:new {
  x = 1, y = 1, w = window.w, h = 1, text = "",
  fg = colors.black, bg = colors.white, wrap = true
}

local scroll = dotui.Scrollable:new {
  x = 1, y = 1, w = window.w, h = base.h,
  fg = colors.black, bg = colors.black,
  child = logtext
}

local function buildLogUI()
  logtext.text = ""
  logtext.h = 0
  for i=1, #logs, 1 do
    logtext.text = logtext.text .. logs[i] .. "\n"
    logtext.h = logtext.h + math.ceil(#logs[i] / window.w)
  end
  scroll.scrollY = logtext.h - base.h
end

base:addChild(scroll)
logtext.surface = scroll.surface

while not window.delete do
  buildLogUI()
  window:draw()
  local sig = window:receiveSignal()
  if sig[1] == "mouse_scroll" then
    scroll.scrollY = scroll.scrollY - sig[2]
  elseif sig[1] == "mouse_click" then
    local element = window:find(sig[3], sig[4])
    if element then
      element:callback()
    end
  elseif sig[1] == "mouse_drag" then
    window.dragging = true
  end
end

dotos.exit()
