-- DoT OS main initialization file --

local osPath = ...

-- give the option to boot CraftOS, but only if it's present.
-- due to the way ComputerCraft is licensed, i don't ship the
-- BIOS with .OS, but you can put it at /craftos-bios.lua and
-- get the option to load CraftOS from ROM.
if fs.exists("/craftos-bios.lua") then
  local sel = 1
  local timers = {
    [os.startTimer(1)] = 4,
    [os.startTimer(2)] = 3,
    [os.startTimer(3)] = 2,
    [os.startTimer(4)] = 1,
    [os.startTimer(5)] = 0
  }
  local function nl()
    local x,y=term.getCursorPos()
    term.setCursorPos(1,y+1)
  end
  local trem = 5
  while true do
    term.setBackgroundColor(0x8000)
    term.clear()
    term.setTextColor(1)
    term.setCursorPos(1, 1)
    term.write("** .os boot manager **")nl()
    term.write("please select an option")nl()
    term.write("(use W/S for up/down, D to select)")nl()
    term.write("time left: "..trem)nl()nl()
    term.write((sel == 1 and ":: " or "   ") ..
      ".OS (from "..osPath..")")nl()
    term.write((sel == 2 and ":: " or "   ") ..
      "CraftOS (from /craftos-bios.lua)")nl()
    local sig = table.pack(coroutine.yield())
    if sig[1] == "char" then
      if sig[2] == "w" or sig[2] == "s" then
        sel = (sel == 1 and 2) or 1
      elseif sig[2] == "d" then
        if sel == 2 then
          local handle, err = assert(fs.open("/craftos-bios.lua", "r"))
          local data = handle.readAll()
          handle.close()
          assert((loadstring or load)(data, "=/craftos-bios", "t", _G))()
          return
        else
          break
        end
      end
    elseif sig[1] == "timer" then
      trem = timers[sig[2]] or trem
      if trem == 0 then break end
    end
  end
end

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

-- compatibility with CC:T 1.89.2
table.unpack = table.unpack or unpack

-- package.lua nils out term later
local term = term
for k, v in pairs(palette) do
  term.setPaletteColor(k, v)
end

-- OS API table
_G.dotos = {
  path = "/"..osPath,
  show_logs = true
}
-- this is removed in package.lua later
local dotos = dotos

term.setBackgroundColor(0x1)
term.setTextColor(0x8000)
term.clear()

local w, h = term.getSize()
-- system console logger thingy
local logbuf = {}
local logio
function dotos.log(fmt, ...)
  local msg = string.format(fmt, ...)
  msg = string.format("[%s] %s", os.date("%H:%M:%S",
    math.floor(os.epoch("utc") / 1000)), msg)
  logbuf[#logbuf+1] = msg
  if dotos.show_logs then
    if type(dotos.logio) == "table" then
      pcall(dotos.logio.write, dotos.logio, msg)
    else
      for line in msg:gmatch("[^\n]+") do
        while #line > 0 do
          local ln = line:sub(1, w)
          line = line:sub(#ln + 1)
          term.scroll(1)
          term.setCursorPos(1, h)
          term.write(ln)
        end
      end
    end
  end
  if #logbuf > 4096 then
    table.remove(logbuf, 1)
  end
end

-- return a protected copy of the log buffer
function dotos.getlogs()
  return setmetatable({}, {__index = function(t,k) return logbuf[k] or "" end,
    __len = function() return #logbuf end, __metatable = {}})
end

local function perr(err)
  term.setTextColor(16)
  term.setCursorPos(1, 3)
  term.write("FATAL: " .. err)
  while true do coroutine.yield() end
end


dotos.log("[.os] running from /" .. osPath)

-- argument checking
-- @docs {
-- @header { checkArg }
-- This function provides basic argument checking for all programs running under .OS.
-- @lfunction { 
--   @lfname { checkArg }
--   @lfarg { number n The number of the argument to check }
--   @lfarg { any have The argument to check }
--   @lfarg { string ... The type(s) against which to check the argument }
--   @lfdesc { 
--     Checks whether the argument @monospace { have }'s type is equal to any of the provided types.  If it is not, throws an error.
--   }
-- }
-- }
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
    local aname
    if type(n) == "number" then
      aname = string.format("#%d", n)
    else
      aname = string.format("'%s'", n)
    end
    error(debug.traceback(string.format("bad argument %s (expected %s, got %s)",
      aname, table.concat({...}, " or "), have), 3))
  end
end

-- if we're running in Lua 5.1, replace load() and remove its legacy things
-- (or, rather, place them in dotos.lua51 (for now), where programs that really
-- need them can access them later).
if _VERSION == "Lua 5.1" then
  dotos.lua51 = {
    load = load,
    loadstring = loadstring,
    setfenv = setfenv,
    getfenv = getfenv,
    unpack = unpack,
    log10 = math.log10,
    maxn = table.maxn
  }

  -- we lock dotos.lua51 behind a permissions wall later, so set it as an
  -- upvalue here
  local lua51 = dotos.lua51

  function _G.load(x, name, mode, env)
    checkArg(1, x, "string", "function")
    checkArg(2, name, "string", "nil")
    checkArg(3, mode, "string", "nil")
    checkArg(4, env, "table", "nil")
    env = env or _G

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

-- load io library
local handle, err = fs.open(fs.combine(osPath, "/dotos/libraries/io.lua"), "r")
if not handle then
  perr(err)
end
local data = handle.readAll()
handle.close()
local ok, err = load(data, "=io")
if not ok then
  perr(err)
end
_G.io = ok(osPath)

-- load package library
_G.package = dofile("/dotos/libraries/package.lua")
-- install some more essential functions
local loop = dofile("/dotos/core/scheduler.lua")
dofile("/dotos/core/essentials.lua")

local init, err = loadfile("/dotos/init.lua")
if not init then
  perr(err)
end
dotos.spawn(init, ".init")

os.queueEvent("dummy")
loop()
