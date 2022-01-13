-- start the .WM Login Manager --

local dotos = require("dotos")

local wmpid, loginpid
local function restart_wm()
  wmpid = dotos.spawn(function()
    dofile("/dotos/interfaces/dotwm/dotwm.lua")
  end, ".wm")
end

local loginfile = "/dotos/interfaces/dotwm/desktop.lua"
--local loginfile = "/dotos/interfaces/dotwm/wmlogin.lua"

local function restart_login()
  loginpid = dotos.spawn(function()
    dofile(loginfile)
  end, "login")
end

restart_wm()
restart_login()

while true do
  coroutine.yield()
  if not dotos.running(wmpid) then
    restart_wm()
  end
  if not dotos.running(loginpid) then
    restart_login()
  end
end
