-- .UI menu --

local dotui = require("dotui")
local fs = require("fs")

local window = dotui.window.create(1, 2, 16, 4)
local base = dotui.Menu:new {
  x = 1, y = 1, w = window.w, h = window.h,
}
window:addPage("main", base)

local desktopFilePaths = {
  "/dotos/appdefs/",
  "/user/appdefs/"
}

base:addItem("Shut Down", function()
  dotui.util.loadApp(".shutdown", "/dotos/dotui/shutdown.lua")
  window.delete = true
end)

window.h = 1
for i, path in ipairs(desktopFilePaths) do
  if fs.exists(path) then
    local files = fs.list(path)
    window.h = window.h + #files
    for i, file in ipairs(files) do
      local handle = io.open(path..file, "r")
      local data = handle:read("a")
      handle:close()
      local func, err = load("return " .. data, "="..file, "t", {})
      if not func then
        dotos.spawn(function()
          dotui.util.prompt(err, {"OK", title = "App Load Error"})
          dotos.exit()
        end, ".appDescErr")
      else
        local desc = func()
        base:addItem(desc.name, function()
          window.delete = true
          dotui.util.loadApp(desc.procname, desc.exec)
        end)
      end
    end
  end
end
base.h = window.h
window.buffer:resize(window.w, window.h)

while not window.delete do
  window:draw()
  local sig = window:receiveSignal()
  if sig[1] == "unfocus" then
    window.delete = true
  elseif sig[1] == "mouse_click" then
    local element = window:find(sig[3], sig[4])
    if element then element:callback() end
  end
end

dotos.exit()
