-- login --

local dotos = require("dotos")
local users = require("users")
local tk = require("dottk")
local wm = require("dotwm")
local colors = require("colors")

local root 
repeat
  root = wm.connect()
  if not root then coroutine.yield() end
until root

local logged_in = false

local uname, pass = "", ""
local win = tk.Window:new({
  w = 12, h = 7,
  root = root,
  position = "centered"
})


local pid 
local status = ""
local status_col = colors.white
local status_bg

local layout = tk.Grid:new({
  w = 12, h = 7,
  rows = 7, cols = 1,
  window = win,
}):addChild(1, 1, tk.Text:new({
  window = win,
  text = ".OS Login",
  position = "center"
})):addChild(6, 1, tk.Text:new({
  window = win,
  text = function(self)
    self.textcol = status_col
    self.bgcol = status_bg
    return status
  end,
  --position = "center",
})):addChild(2, 1, tk.Text:new({
  window = win,
  text = "Username",
  position = "center"
})):addChild(3, 1, tk.InputBox:new({
  window = win,
  position = "center",
  width = 0.8,
  onchar = function(self)
    uname = self.buffer
  end
})):addChild(4, 1, tk.Text:new({
  window = win,
  text = "Password",
  position = "center",
})):addChild(5, 1, tk.InputBox:new({
  window = win,
  position = "center",
  width = 0.8,
  mask = "\7",
  onchar = function(self)
    pass = self.buffer
  end
})):addChild(7, 1, tk.Grid:new({
  window = win,
  w = 10, h = 1,
  rows = 1, cols = 2,
}):addChild(1, 2, tk.Button:new({
  window = win,
  text = "Log In",
  callback = function(self)
    if users.auth(uname, pass) then
      local _
      root.removeWindow(win.windowid)
      _, pid = users.runas(uname, pass, function()
        local ok, err = loadfile("/dotos/interfaces/dotwm/desktop.lua", "DE")
        if not ok then
          status = "Failed"
          status_col = colors.red
          status_bg = colors.white
        else
          logged_in = true
          ok()
        end
      end, ".desktop")
    else
      status_col = colors.red
      status_bg = colors.white
      status = "Bad Login"
    end
  end
})))

while true do
  win:addChild(1, 1, layout)
  while not logged_in do
    coroutine.yield()
  end
  while dotos.running(pid) do
    coroutine.yield()
  end
  logged_in = false
end
