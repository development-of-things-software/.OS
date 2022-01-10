-- keyboard related things --

local dotos = require("dotos")

-- automatic keymap detection :)
local kmap = "lwjgl3"
local mcver = tonumber(_HOST:match("%b()"):sub(2,-2):match("1%.(%d+)")) or 0
if mcver <= 12 or _HOST:match("CraftOS%-PC") then
  -- use the 1.12.2 keymap
  kmap = "lwjgl2"
end

local base = dofile("/dotos/resources/keys/"..kmap..".lua")
local lib = {}

-- reverse-index it!
for k, v in pairs(base) do lib[k] = v; lib[v] = k end
lib["return"] = lib.enter

local pressed = {}
dotos.handle("key", function(_, k)
  pressed[k] = true
end)

dotos.handle("key_up", function(_, k)
  pressed[k] = false
end)

function lib.pressed(k)
  checkArg(1, k, "number")
  return not not pressed[k]
end

function lib.ctrlPressed()
  return pressed[lib.leftControl] or pressed[lib.rightControl]
end

return lib
