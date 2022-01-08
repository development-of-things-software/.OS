-- start the configured interface --

local dotos = require("dotos")
local iface = require("settings").sysget("interface") or "dotsh"

local path = "/dotos/interfaces/?/main.lua;/shared/interfaces/?/main.lua"
local ifacepath = package.searchpath(iface, path)

if not ifacepath then
  dotos.log("[90_interface] !!WARNING!! The interface '" .. iface .. "' was not found!")
  dotos.log("[90_interface] Defaulting to 'dotsh'")
  os.sleep(2)
  ifacepath = package.searchpath("dotsh", path)
end

dotos.spawn(function()
  dofile(ifacepath)
end, iface)
