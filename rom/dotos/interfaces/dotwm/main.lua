-- start the .WM Login Manager --

local dotos = require("dotos")

local wmpid, loginpid
local function restart_wm()
  wmpid = dotos.spawn(function()
    dofile("/dotos/interfaces/dotwm/dotwm.lua")
  end, ".wm")
end

local function restart_login()
  loginpid = dotos.spawn(function()
    dofile("/dotos/interfaces/dotwm/wmlogin.lua")
  end, "login")
end

error("no")

restart_wm()
restart_login()

local lastfail = os.epoch("utc")

while true do
  coroutine.yield()
  local newtime = os.epoch("utc")
  if not dotos.running(wmpid) then
    if newtime - lastfail <= 750 then dotos.exit() end
    lastfail = newtime
    restart_wm()
  end
  if not dotos.running(loginpid) then
    if newtime - lastfail <= 750 then dotos.exit() end
    lastfail = newtime
    restart_login()
  end
end
