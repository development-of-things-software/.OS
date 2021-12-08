-- keyboard related things --

local settings = require("settings")
local kmap = settings.sysget("keyboardLayout")

local base = dofile("/dotos/resources/keys/"..kmap..".lua")

-- reverse-index it!
for k, v in pairs(base) do base[k] = v end

return base
