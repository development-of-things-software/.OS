-- login --

local dotos = require("dotos")
local users = require("users")
local tk = require("dottk")
local wm = require("dotwm")

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

win:addChild(1, 1, tk.Grid:new({
  w = 12, h = 7,
  rows = 7, cols = 1,
  window = win,
}):addChild(1, 1, tk.Text:new({
  window = win,
  text = ".OS",
  position = "center"
})):addChild(3, 1, tk.Text:new({
  window = win,
  text = "Username",
  position = "center"
})):addChild(4, 1, tk.InputBox:new({
  window = win,
  position = "center",
  width = 0.8,
  onchar = function(self)
    uname = self.buffer
  end
})):addChild(5, 1, tk.Text:new({
  window = win,
  text = "Password",
  position = "center",
})):addChild(6, 1, tk.InputBox:new({
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
  text = "Login",
  callback = function(self)
    if users.auth(uname, pass) then
      users.runas(uname, pass, function()
        dofile("/dotos/interfaces/dotwm/desktop.lua")
      end, ".desktop")
      logged_in = true
    else
      self.textcol = tk.colors.text_disabled
    end
  end
}))))

while not logged_in do
  coroutine.yield()
end
