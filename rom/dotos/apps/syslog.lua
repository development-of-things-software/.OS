-- view system logs --

local dotui = require("dotui")
local surface = require("surface")
local textutils = require("textutils")

local window, base = dotui.util.basicWindow(2, 2, 40, 14, "System Logs")

local logs = dotos.getlogs()
local logtext = dotui.Label:new {
  x = 1, y = 1, w = window.w, h = 1, text = "",
  wrap = true
}

local scroll = dotui.Scrollable:new {
  x = 1, y = 1, w = window.w, h = base.h,
  child = logtext,
}

local function buildLogUI()
  logtext.text = ""
  logtext.h = 0
  for i=1, #logs, 1 do
    logtext.text = logtext.text .. logs[i] .. "\n"
    logtext.h = logtext.h + #textutils.wordwrap(logs[i], window.w)
  end
  logtext.surface:resize(window.w, logtext.h)
end

buildLogUI()

base:addChild(scroll)
dotui.util.genericWindowLoop(window, {generic = buildLogUI})

dotos.exit()
