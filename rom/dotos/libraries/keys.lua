-- keyboard related things --

local settings = require("settings")
local kmap = settings.sysget("keyboardLayout")

local base = dofile("/dotos/resources/keys/"..kmap..".lua")

-- reverse-index it!
for k, v in pairs(base) do base[k] = v end

local pressed = {}
dotos.handle("key", function(_, k)
  pressed[k] = true
end)

dotos.handle("key_up", function(_, k)
  pressed[k] = false
end)

function base.pressed(k)
  checkArg(1, k, "number")
  return not not pressed[k]
end

return base
