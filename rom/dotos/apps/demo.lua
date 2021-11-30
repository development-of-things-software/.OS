-- UI toolkit demo --

local dotui = require("dotui")
local colors = require("colors")

local window, base = dotui.util.basicWindow(2, 2, 30, 12, "UI Demo")

local long = dotui.UIPage:new {
  x = 1, y = 1, w = window.w, h = 41
}

local long2 = dotui.UIPage:new {
  x = 1, y = 1, w = window.w, h = 16
}

local text = [[
This is a demo of .OS's UI framework.

It supports word-wrapping, scrolling, and a host of other features.

Currently available controls are buttons, switches, sliders, and drop-downs:














Currently available apps are a task manager, system settings, a system log viewer, and this demo.  Clicking "Shut Down" in the menu presents a convenient shutdown dialog.

As you have probably noticed, scrollable views automatically render a scrollbar at their rightmost edge.
]]

local text2 = [[
This is a nested scrollable element.  Try scrolling it!

The desktop supports forcing windows into the background; this is how the desktop is drawn.  Try killing the 'desktop' process in the Task Manager.

As you can see, nested scrollable elements work as expected.
]]

long:addChild(dotui.Label:new {
  x = 2, y = 2, w = base.w - 4, h = 1, text = text, wrap = true
})

long2:addChild(dotui.Label:new {
  x = 1, y = 1, w = base.w - 6, h = 1, text = text2, wrap = true
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

local scroll2 = dotui.Scrollable:new {
  x = 3, y = 18, w = window.w - 4, h = 8, child = long2
}

long:addChild(scroll2)

base:addChild(scroll)

dotui.util.genericWindowLoop(window)

dotos.exit()
