-- inter-process communication through message queues --

local dotos = require("dotos")

local lib = {}

local channels = {}
local open = {}

-- basic IPC primitives
local raw = {}
lib.raw = raw

function raw.open(id)
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
  local pid = dotos.getpid()
  open[pid] = open[pid] or {}
  table.insert(open[pid], n)
  return n
end

function raw.isopen(id)
  checkArg(1, id, "number")
  return not not channels[id]
end

function raw.close(n)
  checkArg(1, n, "number")
  if not channels[n] then
    return nil, "IPC channel not found"
  end
  channels[n] = nil
  return true
end

function raw.send(n, ...)
  checkArg(1, n, "number")
  if not channels[n] then
    return nil, "IPC channel not found"
  end
  local msg = table.pack(n, ...)
  if msg.n == 1 then return end
  table.insert(channels[n].send, msg)
  return true
end

function raw.respond(n, ...)
  checkArg(1, n, "number")
  if not channels[n] then
    return nil, "IPC channel not found"
  end
  local msg = table.pack(...)
  if msg.n == 0 then return end
  table.insert(channels[n].recv, msg)
  return true
end

function raw.receive(n, wait)
  checkArg(1, n, "number", "nil")
  if not n then
    local id = dotos.getpid()
    while true do
      for i, chan in ipairs(channels) do
        if chan.to == id and #chan.send > 0 then
          local t = table.remove(chan.send, 1)
          return table.unpack(t, 1, t.n)
        end
      end
      if wait then
        coroutine.yield()
      else
        break
      end
    end
  else
    if not channels[n] then
      return nil, "IPC channel not found"
    end
    if wait then
      while #channels[n].recv == 0 do coroutine.yield() end
    end
    if #channels[n].recv > 0 then
      local t = table.remove(channels[n].recv, 1)
      return table.unpack(t, 1, t.n)
    end
  end
end

local stream = {}
function stream:sendAsync(...)
  if not raw.isopen(self.id) then self.id = raw.open(self.name) end
  return raw.send(self.id, ...)
end

function stream:receiveAsync()
  if not raw.isopen(self.id) then self.id = raw.open(self.name) end
  return raw.receive(self.id)
end

function stream:receive()
  if not raw.isopen(self.id) then self.id = raw.open(self.name) end
  return raw.receive(self.id, true)
end

function stream:send(...)
  local ok, err = self:sendAsync(...)
  if not ok then return nil, err end
  return self:receive()
end

function stream:close()
  if not raw.isopen(self.id) then
    raw.close(self.id)
  end
end

function lib.connect(name)
  checkArg(1, name, "string")
  local id, err = raw.open(name)
  if not id then return nil, err end
  return setmetatable({name=name,id=id},{__index=stream})
end

local proxy_mt = {
  __index = function(t, k)
    if t.conn[k] then
      return function(_, ...)
        return t.conn[k](t.conn, ...)
      end
    else
      return function(_, ...)
        return t.conn:send(k, ...)
      end
    end
  end
}

function lib.proxy(name)
  checkArg(1, name, "string")
  local conn, err = lib.connect(name)
  if not conn then return nil, err end
  return setmetatable({name=name,conn=conn}, proxy_mt)
end

function lib.listen(api)
  checkArg(1, api, "table")
  while true do
    local request = table.pack(raw.receive())
    if request.n > 0 then
      if not api[request[2]] then
        raw.respond(request[1], nil, "bad api request")
      else
        local req = table.remove(request, 2)
        local result = table.pack(pcall(api[req],
          table.unpack(request, 1, request.n)))
        if result[1] then
          table.remove(result, 1)
        end
        raw.respond(request[1], table.unpack(result, 1, result.n))
      end
    else
      coroutine.yield()
    end
  end
end

-- close IPC streams when threads die
dotos.handle("thread_died", function(id)
  if open[id] then
    for i, handle in ipairs(open[id]) do
      raw.close(handle)
    end
  end
end, true)

return lib
