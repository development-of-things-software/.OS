-- inter-process communication through message queues --

local dotos = require("dotos")

local lib = {}

local registry = {}
local channels = {}

-- basic IPC primitives
lib.raw = {}

function lib.raw.open(id)
  checkArg(1, id, "number", "string")
  if type(id) == "string" then
    for k, v in pairs(dotos.listthreads()) do
      if v.name == id then id = v.id break end
    end
  end
  if type(id) == "string" or not dotos.running(id) then
    return nil, "IPC target not found"
  end
  local n = #channels + 1
  channels[n] = {to = id, send = {}, recv = {}}
  return n
end

function lib.raw.isopen()
end

local _ipc = {}

-- timeout is accurate to whatever the scheduler resume delay is - usually 0.5s
function _ipc:wait(timeout)
  timeout = timeout or math.huge
  local id = os.startTimer(timeout)
  while #self.queue == 0 do
    local sig, tid = coroutine.yield()
    if sig == "timer" and tid == tid then
      if #self.queue == 0 then
        return nil, "IPC request timed out"
      end
    end
  end
  return table.unpack(table.remove(self.queue, 1))
end

function _ipc:send(...)
  self.queue[#self.queue+1] = table.pack(...)
end

function _ipc.new()
  return setmetatable({queue={},root=}, {__index=_ipc})
end

function lib.register(name, callback)
end

function lib.connect()
end

return lib
