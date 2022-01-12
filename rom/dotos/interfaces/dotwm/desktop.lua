-- .OS Desktop Interface --

local fs = require("fs")
local tk = require("dottk")
local wm = require("dotwm")

local root
repeat
  root = wm.connect()
  coroutine.yield()
until root

local height = 6
local rf, uf = fs.list("/dotos/appdefs"), fs.list("/shared/appdefs")
if rf then height = height + #rf end
if uf then height = height + #uf end

local window = tk.Window:new({
  root = root,
  w = 15,
  h = height,
})

local reboot = false

local grid = tk.Grid:new({
  window = window,
  rows = height - 1,
  columns = 1
}):addChild(1, 1, tk.Text:new{
  window = window,
  text = " "..("\x8c"):rep(13).." ",
}):addChild(2, 1, tk.Button:new{
  window = window,
  text = "Settings",
  position = "center",
}):addChild(height - 3, 1, tk.Text:new{
  window = window,
  text = " "..("\x8c"):rep(13).." ",
}):addChild(height - 2, 1, tk.Checkbox:new{
  window = window,
  text = "Restart?",
  callback = function(self) reboot = self.selected end
}):addChild(height - 1, 1, tk.Button:new{
  window = window,
  text = "Shut Down",
  position = "center",
  callback = function() if reboot then os.reboot() else os.shutdown() end end,
})

local function readfile(f)
  local handle = io.open(f, "r")
  local data = handle:read("a")
  handle:close()
  return data
end

if rf then
  for i, f in ipairs(rf) do
    local ok, err = load("return"..readfile("/dotos/appdefs/"..f), "="..f,
      "t", {})
    if ok then
      local def = ok()
      grid:addChild(i + 2, 1, tk.Button:new{
        window = window,
        text = def.name,
        position = "center",
      })
    else
      grid:addChild(i + 2, 1, tk.Text:new{
        window = window,
        text = "load failed",
        position = "center"
      })
    end
  end
end

window:addChild(1, 1, tk.TitleBar:new{
  window = window,
  text = "Menu"
}):addChild(1, 2, grid)

while true do
  coroutine.yield()
  if window.closed then
    window.closed = false
    root.addWindow(window)
  end
end
