-- VT100 layer over top of a surface --

local textutils = require("textutils")

local lib = {}

local vts = {}

local function corral(s)
  while s.cx < 1 do
    s.cy = s.cy - 1
    s.cx = s.cx + s.surface.w
  end

  while s.cx >= s.surface.w do
    s.cy = s.cy + 1
    s.cx = s.cx - s.surface.w
  end
  
  while s.cy < 1 do
    s:scroll(-1)
    s.cy = s.cy + 1
  end

  while s.cy > s.surface.h do
    s:scroll(1)
    s.cy = s.cy - 1
  end
end

function vts:scroll(n)
  -- TODO: this works for scrolling up, but not for scrolling down
  self.surface:blit(self.surface, 1, -n)
end

function vts:raw_write(str)
  checkArg(1, str, "string")
  for _,line in ipairs(textutils.lines(str)) do
    while #line > 0 do
      local chunk = line:sub(1, self.surface.w - self.cx)
      line = line:sub(#chunk + 1)
      self.surface:set(self.cx, self.cy, )
      self.cx = self.cx + w
      corral(self)
    end
  end
end

function vts:write(str)
  checkArg(1, str, "string")
  -- hide cursor
  local cc, cf, cb = self.surface:get(self.cx, self.cy, 1)
  self.surface:rawset(self.cx, self.cy, cb, cf)
  while #str > 0 do
    local nesc = str:find("\27")
    local e = nesc or #str
    local chunk = str:sub(1, e - 1)
    str = str:sub(e)
    self:raw_write(chunk)
    if nesc then
      local css, paramdata, csc, len = str:match("\27[%[%?]([%d;]*)%()")
      str = str:sub(len)
      local args = {}
      for n in paramdata:gmatch("[^;]+") do
        args[#args+1] = tonumber(n)
      end
      if css == "[" then
        -- minimal subset of the standard
        if csc == "A" then
          args[1] = args[1] or 1
        elseif csc = "B" then
          args[1] = args[1] or 1
        elseif csc == "C" then
          args[1] = args[1] or 1
        elseif csc == "D" then
          args[1] = args[1] or 1
        elseif csc == "E" then
          args[1] = args[1] or 1
        elseif csc == "F" then
          args[1] = args[1] or 1
        elseif csc == "G" then
          args[1] = args[1] or 1
        elseif csc == "f" or csc == "H" then
          args[1] = args[1] or 1
          args[2] = args[2] or 1
        elseif csc == "m" then
          args[1] = args[1] or 0
        end
      elseif css = "?" then
      end
    end
  end
  -- show cursor
  local cc, cf, cb = self.surface:get(self.cx, self.cy, 1)
  self.surface:rawset(self.cx, self.cy, cb, cf)
end

function lib.new(surf)
  checkArg(1, surf, "table")
  return setmetatable({
    cx = 1, cy = 1,
  }, {__index = vts, __metatable = {}})
end

return lib
