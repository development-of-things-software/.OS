-- scheduler --

local threads = {}
local current = 0

local default_stream = {
  readAll = function() end,
  readLine = function() end,
  write = function(str) dotos.log(str) end,
  flush = function() end,
  seek = function() end,
  close = function() end,
}
default_stream = dotos.mkfile(default_stream, "rwb")
local default_thread = {io = {}, env = {}}

function dotos.spawn(func, name, root)
  checkArg(1, func, "function")
  checkArg(2, name, "string")
  checkArg(3, root, "string", "nil")
  local parent = threads[current] or default_thread
  local thread = {
    coro = coroutine.create(func),
    env = {},
    io = {
      stdin = parent.io.stdin or default_stream,
      stdout = parent.io.stdout or default_stream,
      stderr = parent.io.stderr or default_stream,
    },
    pwd = parent.pwd or "/",
    root = root or parent.root or "/"
  }
  threads[#threads+1] = thread
end

function dotos.getpwd()
  return (threads[current] or default_thread).pwd
end

function dotos.getroot()
  return (threads[current] or default_thread).root
end

function dotos.getio(field)
  return (threads[current] or default_thread).io[field] or default_stream
end

function dotos.exit()
  threads[current] = nil
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
    for k, v in pairs(threads) do
      local ok, res = coroutine.resume(v.coro, table.unpack(signal, 1,
        signal.n))
      if not ok then
        dotos.log("[.os] thread %s failed: %s", k, res)
        threads[k] = nil
      end
    end
  end
  dotos.log("[.os] init thread has stopped")
  os.sleep(3)
  os.shutdown()
end

return loop
