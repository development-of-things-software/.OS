-- DoT OS main initialization file --

local osPath = ...

local palette = {
  -- black
  [00001] = 0x000000,
  -- dark and light gray
  [00002] = 0x606060,
  [00004] = 0xb0b0b0,
  -- reds
  [00008] = 0xaa0000,
  [00016] = 0xff0000,
  -- greens
  [00032] = 0x00aa00,
  [00064] = 0x00ff00,
  -- blues
  [00128] = 0x0080ff,
  [00256] = 0x66b6ff,
  -- purples
  [00512] = 0x6000aa,
  [01024] = 0x9000ff,
  -- brown and yellow
  [02048] = 0x6030f0,
  [04096] = 0xffff00,
  -- orange and cyan
  [08192] = 0xff8000,
  [16384] = 0x40ffff,
  -- white
  [32768] = 0xFFFFFF
}

for k, v in pairs(palette) do
  term.setPaletteColor(k, v)
end

term.setBackgroundColor(256)
term.setTextColor(0x8000)
term.clear()
term.setCursorPos(1, 1)
term.write(".OS is starting...")
term.setCursorPos(1, 2)
term.write(".OS running from " .. osPath)

-- OS API table
_G.dotOS = {}

-- argument checking
function checkArg(n, have, ...)
  have = type(have)
  local function check(want, ...)
    if not want then
      return false
    else
      return have == want or check(...)
    end
  end
  if not check(...) then
    error(string.format("bad argument #%d (expected %s, got %s",
      n, table.concat({...}, " or "), have))
  end
end

-- if we're running in Lua 5.1, replace load() and remove its legacy things
-- (or, rather, place them in dotOS.lua51 (for now), where programs that really
-- need them can access them later).
if _VERSION == "Lua 5.1" then
  dotOS.lua51 = {
    load = load,
    loadstring = loadstring,
    setfenv = setfenv,
    getfenv = getfenv,
    unpack = unpack,
    log10 = math.log10,
    maxn = table.maxn
  }

  -- we lock dotOS.lua51 behind a permissions wall later, so set it as an
  -- upvalue here
  local lua51 = lua51

  function _G.load(x, name, mode, env)
    checkArg(1, x, "string", "function")
    checkArg(2, name, "string", "nil")
    checkArg(3, mode, "string", "nil")
    checkArg(4, env, "table", "nil")

    local result, err
    if type(x) == "string" then
      result, err = lua51.loadstring(x, name)
    else
      result, err = lua51.load(x, name)
    end
    if result then
      env._ENV = env
      lua51.setfenv(result, env)
    end
    return result, err
  end

  _G.setfenv = nil
  _G.getfenv = nil
  _G.loadstring = nil
  _G.unpack = nil
  _G.math.log10 = nil
  _G.table.maxn = nil
end

-- system console logger thingy
local logbuf = {}
function dotOS.log(fmt, ...)
  local msg = string.format(fmt, ...)
  logbuf[#logbuf+1] = msg
  if #logbuf > 4096 then
    table.remove(logbuf, 1)
  end
end

local function perr(err)
  term.setTextColor(16)
  term.setCursorPos(1, 3)
  term.write("FATAL: " .. err)
  while true do coroutine.yield() end
end

-- load io library
local handle, err = fs.open(fs.combine(osPath, "/dotos/libraries/io.lua"), "r")
if not handle then
  perr(err)
end
local data = handle.readAll()
handle.close()
local ok, err = load(data)
if not ok then
  perr(err)
end
_G.io = ok(osPath)

-- load package library
_G.package = dofile("/dotos/libraries/package.lua")

while true do coroutine.yield() end
