-- dynamically start/stop/suspend interfaces --

local dotos = require("dotos")
local ipc = require("ipc")

local path = "/dotos/interfaces/?/main.lua;/shared/interfaces/?/main.lua"

local running = {dynamic = dotos.getpid()}
local current
local api = {}

-- start an interface and switch to it
function api.start(_, iface)
  checkArg(1, iface, "string")
  if running[iface] then
    if current ~= iface then
      dotos.stop(running[current])
      dotos.continue(running[iface])
    end
    return true
  end

  local path = package.searchpath(iface, path)
  if not path then
    return nil, "Interface not found"
  end
  
  local pid = dotos.spawn(function()
    dofile(path)
  end, iface)
  running[iface] = pid
  
  if current then
    dotos.stop(running[current])
  end
  
  current = iface
  return true
end

-- stop an interface
function api.stop(_, iface)
  if not running[iface] then
    return nil, "That interface is not running"
  end
  if iface == "dynamic" then
    return nil, "Refusing to stop self"
  end
  dotos.kill(running[iface])
  running[iface] = nil
  return true
end

local configured = require("settings").sysget("interface") or "dotsh"
if configured == "dynamic" or not api.start(nil, configured) then
  api.start(nil, "dotsh")
end

dotos.handle("thread_died", function(_, pid)
  for k, v in pairs(running) do
    if pid == v then
      running[k] = nil
      dotos.log("INTERFACE CRASHED - STARTING dotsh")
      os.sleep(2)
      os.queueEvent("boy do i love hacks")
      api.start(nil, "dotsh")
    end
  end
end)

ipc.listen(api)
