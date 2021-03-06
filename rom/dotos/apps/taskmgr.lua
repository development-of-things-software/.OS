-- task manager --

local dotos = require("dotos")
local dotui = require("dotui")
local colors = require("dotui.colors")

local window, base = dotui.util.basicWindow(2, 2, 30, 12, "Task Manager")

local taskmenu = dotui.Selector:new {
  x = 1, y = 1, w = window.w, h = 1, exclusive = true,
}

local scroll = dotui.Scrollable:new {
  x = 2, y = 3, w = window.w, h = base.h - 3,
  child = taskmenu
}

-- button bar at the top of the screen
local buttons = dotui.UIPage:new {
  x = 1, y = 1, w = window.w, h = 1,
  bg = colors.clickable_bg_default
}

local threads
base:addChild(buttons)
buttons:addChild(dotui.Clickable:new {
  x = 2, y = 1, w = 6, h = 1, text = " Kill ",
  callback = function()
    for k in pairs(taskmenu.selected) do
      if threads[k] then
        local answer = dotui.util.prompt("Really kill this process?",
          {"Yes", "No", title = "Confirmation"})
        if answer == "Yes" then
          dotos.kill(threads[k].id)
        end
        break
      end
    end
  end
})

local function buildTaskUI()
  taskmenu.items = {}
  threads = dotos.listthreads()
  taskmenu.h = #threads
  for i=1, #threads, 1 do
    taskmenu:addItem(string.format("%4d  %s", threads[i].id, threads[i].name))
  end
  taskmenu.surface:resize(taskmenu.w, taskmenu.h)
end

base:addChild(scroll)

dotui.util.genericWindowLoop(window, {generic = buildTaskUI})

dotos.exit()
