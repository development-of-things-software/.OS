-- start the configured interface --

local dotos = require("dotos")
local iface = require("settings").sysget("interface") or "dotui"

dotos.spawn(function()
  dofile("/dotos/interfaces/"..iface.."/main.lua")
end, iface)
