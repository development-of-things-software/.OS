-- scheduler --

local users = dofile("/dotos/core/users.lua")
package.loaded.users = users
local fs = require("fs")
local dotos = require("dotos")

local threads = {}
local current = 0
local max = 0

local default_stream = {
  readAll = function() end,
  readLine = function() end,
  write = function(str) dotos.log(str) end,
  flush = function() end,
  seek = function() end,
  close = function() end,
}
default_stream = dotos.mkfile(default_stream, "rwb")
local default_thread = {io = {}, env = {TERM = "cynosure", HOME = "/"}}

function dotos.spawn(func, name, root)
  checkArg(1, func, "function")
  checkArg(2, name, "string")
  checkArg(3, root, "string", "nil")
  local parent = threads[current] or default_thread
  local nenv = {}
  if parent.env then
    for k,v in pairs(parent.env) do nenv[k] = v end
  end
  local thread = {
    coro = coroutine.create(func),
    env = nenv,
    io = {
      stdin = parent.io.stdin or default_stream,
      stdout = parent.io.stdout or default_stream,
      stderr = parent.io.stderr or default_stream,
    },
    pwd = parent.pwd or "/",
    root = root or parent.root or "/",
    name = name,
    user = parent.user or "admin",
  }
  max = max + 1
  threads[max] = thread
  return max
end

function dotos.getenv(k)
  if not k then return threads[current].env end
  checkArg(1, k, "string")
  return threads[current].env[k]
end

function dotos.setenv(k, v)
  checkArg(1, k, "string")
  threads[current].env[k] = v
end

function dotos.getpwd()
  return (threads[current] or default_thread).pwd
end

function dotos.setpwd(path)
  checkArg(1, path, "string")
  local t = threads[current] or default_thread
  if path:sub(1,1) ~= "/" then path = fs.combine(t.pwd, path) end
  if not fs.exists(path) then return nil, "no such file or directory" end
  if not fs.isDir(path) then return nil, "not a directory" end
  t.pwd = path
end

function dotos.getroot()
  return (threads[current] or default_thread).root
end

function dotos.getio(field)
  checkArg(1, field, "string")
  return (threads[current] or default_thread).io[field] or default_stream
end

function dotos.setio(field, file)
  checkArg(1, field, "string")
  checkArg(2, file, "table")
  local t = threads[current] or default_thread
  t.io[field] = file
  return true
end

function dotos.running(id)
  checkArg(1, id, "number")
  return not not threads[id]
end

function dotos.getpid()
  return current
end

function dotos.kill(id)
  checkArg(1, id, "number")
  threads[id] = nil
end

function dotos.getuser()
  return (threads[current] or default_thread).user
end

function dotos.setuser(name)
  checkArg(1, name, "string")
  if dotos.getuser() ~= "admin" then
    return nil, "permission denied"
  end
  if users.exists(name) then
    threads[current].user = name
    return true
  else
    return nil, "that user does not exist"
  end
end

users.threads(threads)

function dotos.listthreads()
  local t = {}
  for k,v in pairs(threads) do
    t[#t+1] = {id=k, name=v.name}
  end
  table.sort(t, function(a,b)
    return a.id < b.id
  end)
  return t
end

function dotos.stop(id)
  checkArg(1, id, "number")
  if not threads[id] then return nil, "no such thread" end
  threads[id].stopped = true
  return true
end

function dotos.continue(id)
  checkArg(1, id, "number")
  if not threads[id] then return nil, "no such thread" end
  threads[id].stopped = false
  return true
end

local handlers = {}
local hn = 0
function dotos.handle(sig, func, persist)
  checkArg(1, sig, "string")
  checkArg(2, func, "function")
  checkArg(3, persist, "boolean", "nil")
  hn = hn + 1
  handlers[hn] = {registrar = persist and 0 or current, sig = sig, func = func}
  return hn
end

function dotos.drop(n)
  checkArg(1, n, "number")
  handlers[n] = nil
  return true
end

local function deregister_handlers(id)
  for k, v in pairs(handlers) do
    if v.registrar == id then
      handlers[k] = nil
    end
  end
end

function dotos.exit()
  threads[current] = nil
  deregister_handlers(current)
  coroutine.yield()
end

local function loop()
  local lastTimerID
  while threads[1] do
    if not lastTimerID then
      lastTimerID = os.startTimer(0.5)
    end
    local signal = table.pack(coroutine.yield())
    if signal[1] == "timer" and signal[2] == lastTimerID then
      lastTimerID = nil
      signal = {n=0}
    end
    if signal.n > 0 then
      for i, handler in pairs(handlers) do
        if signal[1] == handler.sig then
          local ok, err = pcall(handler.func, table.unpack(signal, 1, signal.n))
          if not ok then
            dotos.log("signal handler error: " .. err)
          end
        end
      end
    end
    for k, v in pairs(threads) do
      if not v.stopped then
        current = k
        local ok, res = coroutine.resume(v.coro, table.unpack(signal, 1,
          signal.n))
        if not ok then
          dotos.log("[.os] thread %s failed: %s", k, res)
          deregister_handlers(v.id)
          os.queueEvent("thread_died", k, res)
          threads[k] = nil
        end
      end
    end
  end
  dotos.log("[.os] init thread has stopped")
  os.sleep(10)
  os.shutdown()
end

return loop
