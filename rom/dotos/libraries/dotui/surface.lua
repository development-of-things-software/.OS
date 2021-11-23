-- .UI surfaces --
-- these are more or less windows, but they assume client-side decorations

local buf = require("dotui.buffer")

--- pseudoglobal table of all surfaces ---
local surfaces = {}

local surf = {}

function surf:blit(parent)
  checkArg(1, parent, "table")
  self.buffer:blit(parent.buffer, self.x, self.y)
  return self
end

local api = {}

-- this function may only be called once, for security
function api.getSurfaceTable()
  api.getSurfaceTable = function() end
  return surfaces
end

function api.new(x, y, w, h)
  checkArg(1, x, "number")
  checkArg(2, y, "number")
  checkArg(3, w, "number")
  checkArg(4, w, "number")
end

return api

