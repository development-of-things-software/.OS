-- iostream: Create an IO stream from a surface --
-- allows terminals and whatnot --

local vt = require("vt100")

local s = {}

local lib = {}

function lib.wrap(surface)
  checkArg(1, surface, "table")
  return setmetatable({surface=surface}, {__index = s, __metatable = {}})
end

return lib
