-- library for connection to .WM --

local ipc = require("ipc")

local lib = {}

function lib.connect()
  local channel, err = ipc.proxy(".wm")
  if not channel then return nil, err end
  local result, err = channel:connect()
  channel:close()
  return result
end

return lib
