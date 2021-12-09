-- a proper user system --

local lib = {}

local fs = require("fs")
local settings = require("settings")

local ucfg = "/.users.cfg"

local function ensure()
  if not fs.exists(ucfg) or not settings.get(ucfg, "admin") then
    settings.set(ucfg, "admin", "admin")
  end
end

function lib.exists(name)
  checkArg(1, name, "string")
  ensure()
  return not not settings.get(ucfg, name)
end

return lib
