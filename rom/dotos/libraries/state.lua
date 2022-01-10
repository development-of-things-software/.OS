-- state saving for saving state across service restarts and whatnot --
-- this is NOT for saving state across reboots

local dotos = require("dotos")

local lib = {}

local states = {}

function lib.create(id)
  if id == nil then
    error("bad argument #1 (expected value, got nil)")
  end
  states[id] = states[id] or {}
  if states[id].creator and states[id].creator ~= dotos.getpid()
      and dotos.running(states[id].creator) then
    return nil, "cannot claim another process's state"
  end
  states[id].creator = dotos.getpid()
  return states[id]
end

function lib.discard(id)
  if id == nil then
    error("bad argument #1 (expected value, got nil)")
  end
  local s = states[id]
  if not s then return true end
  if s.creator and dotos.running(s.creator) and s.creator ~= dotos.getpid() then
    return nil, "cannot discard another process's state"
  end
end

return lib
