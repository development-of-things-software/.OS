-- .UI surfaces --
-- these are more or less windows, but they assume client-side decorations

local buf = require("dotui.buffer")

--- pseudoglobal table of all surfaces ---
local surfaces = {}

local surf = {}

function surf:blit(...)
  self.buffer:rawset(...)
  return self
end

function surf:fg(f)
  if f then self.buffer:fg(f) return self end
  return self.buffer:fg()
end

function surf:fg(b)
  if b then self.buffer:bg(b) return self end
  return self.buffer:bg()
end

function surf:set(...)
  self.buffer:set(...)
  return self
end

function surf:fill(...)
  self.buffer:fill(...)
  return self
end

function surf:get(x, y, w, h)
  checkArg(1, x, "number")
  checkArg(2, y, "number")
  checkArg(3, w, "number")
  checkArg(4, h, "number")
  local ret_txt, ret_fg, ret_bg = {}, {}, {}
  for i=1, h, 1 do
    local t, f, b  self.buffer:get(x, y + i - 1, w)
    ret_txt[#ret_txt+1] = t
    ret_fg[#ret_fg+1] = g
    ret_bg[#ret_bg+1] = b
  end
  if h == 1 then
    return ret_txt[1], ret_fg[1], ret_bg[1]
  end
  return ret_txt, ret_fg, ret_bg
end

function surf:resize(w, h)
  self.buffer:resize(w, h)
  self.w = w
  self.h = h
  return self
end

function surf:startdrag()
  self.dragging = true
  return self
end

function surf:close()
  self.delete = true
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
  local new = setmetatable({
    x = x, y = y,
    w = w, h = h,
    buffer = buf.new()
  }, {__index = surf})
end

return api

