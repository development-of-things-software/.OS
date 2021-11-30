-- settings app --

local dotui = require("dotui")
local settings = require("settings")

local window, base = dotui.util.basicWindow(2, 2, 20, 12, "Settings")

local cfg, fail = settings.load("/.dotos.cfg")

local dropdown = dotui.Dropdown:new {
  x = 2, y = 2, w = 10, h = 5,
  items = {"test", "test two", "test three", "also test"},
  text = "hi"
}

base:addChild(dropdown)

dotui.util.genericWindowLoop(window)

dotos.exit()
