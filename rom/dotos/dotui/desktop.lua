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
  x = 1, y = window.h, w = window.w, h = 1,
  fg = colors.gray, bg = colors.lightBlue, text = os.version()
})

local menubar = dotui.UIPage:new {
  x = 1, y = 1, w = window.w, h = 1,
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
  surface = window.buffer,
  text = " Menu "
}

base:addChild(menubar)
menubar:addChild(menubtn)
base:addChild(menu)

-- menu entries
menu:addChild(dotui.Clickable:new {
  x = 1, y = 1, w = 16, h = 1, bg = colors.gray, fg = colors.white,
  text = "Restart", callback = function()
    menu.hidden = not menu.hidden
    local res = dotui.util.prompt("Are you sure you want to reboot?",
      {"Yes", "No", title = "Restart?"})
    if res == "Yes" then
      os.reboot()
    end
  end
})

local function loadApp(file)
  local ok, err = loadfile(file)
  if not ok then
    dotui.util.prompt(err, {"OK", title = "Application Error"})
  end
  dotos.spawn(ok, file)
end

menu:addChild(dotui.Clickable:new {
  x = 1, y = 2, w = 16, h = 1, bg = colors.gray, fg = colors.white,
  text = "System Logs", callback = function()
    menu.hidden = true
    loadApp("/dotos/dotui/syslog.lua")
  end
})

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
      menu.hidden = true
    end
  elseif sig[1] == "thread_died" then
    dotui.util.prompt(sig[3], {"OK",
      title = "Thread " .. sig[2] .. " Died"})
  end
end
