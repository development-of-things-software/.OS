-- task manager --

local dotui = require("dotui")
local colors = require("dotui.colors")

local window, base = dotui.util.basicWindow(2, 2, 30, 12, "Task Manager")

local taskmenu = dotui.Selector:new {
  x = 1, y = 1, w = window.w, h = 1, exclusive = true,
}

local buttons = UIPage:new {
  x = 1, y = 1, w = window.w, h = 2
}

local scroll = dotui.Scrollable:new {
  x = 1, y = 3, w = window.w, h = base.h - 3,
  child = taskmenu
}

local function buildTaskUI()
  taskmenu.items = {}
  local threads = dotos.listthreads()
  for i=1, #threads, 1 do
    taskmenu:addItem(string.format("%4d  %s", threads[i].id, threads[i].name))
  end
end

dotui.util.genericMainLoop()

dotos.exit()
