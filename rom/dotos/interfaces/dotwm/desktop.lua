-- .OS Desktop Interface --

local dotos = require("dotos")
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
        callback = function()
          dotos.spawn(function()
            dofile(def.exec)
          end, def.procname or def.name)
        end,
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

local ok, err = pcall(tk.Dialog.new, tk.Dialog, {
  root = root,
  text = "Error!"
})

if not ok and err then
  local win = tk.Window:new({root=root,w=#err,h=2})
  win:addChild(1,1,tk.TitleBar:new{window=win})
  win:addChild(1,2,tk.Text:new({window=win,text=err}))
end

while true do
  local sig, id, reason = coroutine.yield()
  if window.closed then
    window.closed = false
    root.addWindow(window)
  end
  if sig == "thread_died" then
    tk.Dialog:new {
      root = root,
      text = reason
    }
  end
end
