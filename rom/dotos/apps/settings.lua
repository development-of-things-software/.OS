-- settings app --

local dotui = require("dotui")
local settings = require("settings")

local window, base = dotui.util.basicWindow(2, 2, 30, 12, "Settings")

local settingsTree = {
  keyboardLayout = {"1.16.5", "1.12.2", default = "1.16.5", idefault = 1,
    name = "Keyboard Layout"},
  colorScheme = {"Light", "Dark", default = "Light", idefault = 1,
    name = "Color Scheme"}
}

local settingsOrder = {
  "keyboardLayout", "colorScheme"
}

local cfg, fail = settings.load("/.dotos.cfg")
for k,v in pairs(settingsTree) do
  if cfg[k] then
    v.default = cfg[k]
    for i=1, #v, 1 do
      if v[i] == cfg[k] then v.idefault = i break end
    end
  else
    cfg[k] = v.default
  end
end

local y = 1
for i, set in ipairs(settingsOrder) do
  local k, v = set, settingsTree[set]
  y=y+1
  base:addChild(dotui.Label:new {
    x = 2, y = y, w = 18, h = 1,
    text = v.name
  })
  v.dropdown = dotui.Dropdown:new {
    x = 20, y = y, w = 8, h = 5,
    items = v,
    text = v.default or "empty",
    selected = v.idefault or 1,
  }
end

-- add dropdowns separately so they get drawn on top
for i=#settingsOrder, 1, -1 do
  base:addChild(settingsTree[settingsOrder[i]].dropdown)
end

dotui.util.genericWindowLoop(window)

dotos.exit()
