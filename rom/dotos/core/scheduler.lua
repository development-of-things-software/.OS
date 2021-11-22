-- scheduler --

local threads = {}
local current = 0

local default_stream = {
  readAll = function() end,
  readLine = function() end,
  write = function() end,
  flush = function() end,
  seek = function() end,
  close = function() end,
}
default_stream = dotos.mkfile(default_stream, "rwb")
local default_thread = {io = {}, env = {}}

function dotos.spawn(func, name, root)
  checkArg(1, func, "function")
  checkArg(2, name, "string")
  checkArg(3, root, "string")
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
end

function dotos.getpwd()
  return (threads[current] or default_thread).pwd
end

function dotos.getroot()
  return (threads[current] or default_thread).root
end

local function loop()
  while threads[1] do
    for k, v in pairs(threads) do
    end
  end
  os.shutdown()
end

return loop
