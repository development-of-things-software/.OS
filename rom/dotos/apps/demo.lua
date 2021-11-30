-- UI toolkit demo --

local dotui = require("dotui")
local colors = require("colors")

local window, base = dotui.util.basicWindow(2, 2, 30, 12, "UI Demo")

local long = dotui.UIPage:new {
  x = 1, y = 1, w = window.w, h = 32
}

local text = [[
This is a demo of .OS's UI framework.

It supports word-wrapping, scrolling, and a host of other features.

Currently available controls are buttons, switches, sliders, and drop-downs:





Currently available apps are a task manager, system settings, a system log viewer, and this demo.  Clicking "Shut Down" in the menu presents a convenient shutdown dialog.

As you have probably noticed, scrollable views automatically render a scrollbar at their rightmost edge.
]]

long:addChild(dotui.Label:new {
  x = 2, y = 2, w = base.w - 4, h = 1, text = text, wrap = true
})

long:addChild(dotui.Clickable:new {
  x = 2, y = 14, w = 9, h = 1, text = "Click Me!", callback = function()
    dotui.util.prompt("You clicked the button.", {"OK",
      title = "Oh, and prompts!"})
  end
})

long:addChild(dotui.Slider:new {
  x = 12, y = 16, w = 15, h = 1
})

long:addChild(dotui.Dropdown:new {
  x = 12, y = 14, w = 15, h = 5, items = {
    "Foo", "Bar", "Baz"
  }, selected = 1, text = "Select something"
})

local dynamictext = dotui.Label:new {
  x = 7, y = 16, w = 4, h = 1, text = "OFF",
  fg = colors.red
}

long:addChild(dotui.Switch:new {
  x = 2, y = 16, callback = function(self)
    if self.state then
      dynamictext.fg = colors.green
      dynamictext.text = "ON"
    else
      dynamictext.fg = colors.red
      dynamictext.text = "OFF"
    end
  end
})

long:addChild(dynamictext)

local scroll = dotui.Scrollable:new {
  x = 1, y = 1, w = window.w, h = base.h, child = long
}

base:addChild(scroll)

dotui.util.genericWindowLoop(window)

dotos.exit()
