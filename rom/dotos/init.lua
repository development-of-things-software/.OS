-- .INIT --

local fs = require("fs")
local dotos = require("dotos")

dotos.log("[.init] running startup scripts")

local scripts, err = fs.list("/dotos/startup/")
if not scripts then
  dotos.log("[.init] WARNING: failed getting directory listing")
end
table.sort(scripts)

for i=1, #scripts, 1 do
  dotos.log("[.init] running script %s", scripts[i])
  dofile("/dotos/startup/" .. scripts[i])
end

dotos.log("[.init] starting system interface manager")
dotos.spawn(function()
  dofile("/dotos/core/ifaced.lua")
end, "ifaced")

os.queueEvent("dummy")
while true do coroutine.yield() end
