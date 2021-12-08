-- VT100 layer over top of a surface --

local textutils = require("textutils")
local colors = require("colors")
local vtc = {
  -- standard 8 colors
  colors.black,
  colors.red,
  colors.green,
  colors.orange,
  colors.blue,
  colors.purple,
  colors.brown,
  colors.lightGray,
  -- "bright" colors
  colors.gray,
  colors.lightRed,
  colors.lightGreen,
  colors.yellow,
  colors.lightBlue,
  colors.magenta,
  colors.cyan,
  colors.white
}

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
      self.surface:set(self.cx, self.cy, chunk)
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
          self.cy = self.cy - args[1]
        elseif csc == "B" then
          args[1] = args[1] or 1
          self.cy = self.cy + args[1]
        elseif csc == "C" then
          args[1] = args[1] or 1
          self.cx = self.cx + args[1]
        elseif csc == "D" then
          args[1] = args[1] or 1
          self.cx = self.cx - args[1]
        elseif csc == "E" then
          args[1] = args[1] or 1
          self.cx = 1
          self.cy = self.cy + args[1]
        elseif csc == "F" then
          args[1] = args[1] or 1
          self.cx = 1
          self.cy = self.cy - args[1]
        elseif csc == "G" then
          args[1] = args[1] or 1
          self.cx = args[1]
        elseif csc == "f" or csc == "H" then
          args[1] = args[1] or 1
          args[2] = args[2] or 1
        elseif csc == "J" then
          local c = args[1] or 0
          if c == 0 then
            self.surface:fill(1, 1, self.surface.w, cy, " ")
          elseif c == 1 then
            self.surface:fill(1, cy, self.surface.w, self.surface.h - cy, " ")
          elseif c == 2 then
            self.surface:fill(1, 1, self.surface.w, self.surface.h, " ")
          end
        elseif csc == "K" then
          local c = args[1] or 0
          if c == 0 then
            self.surface:fill(self.cx, self.cy, self.surface.w - self.cx, 1,
              " ")
          elseif c == 1 then
            self.surface:fill(1, self.cy, self.cx, 1, " ")
          elseif c == 2 then
            self.surface:fill(1, self.cy, self.surface.w, 1, " ")
          end
        elseif csc == "m" then
          args[1] = args[1] or 0
          for _, c in ipairs(args) do
            if c == 0 then
              self.surface:fg(colors.lightGray)
              self.surface:bg(colors.black)
            elseif c > 29 and c < 38 then
              self.surface:fg(colors[c - 29])
            elseif c > 39 and c < 48 then
              self.surface:bg(colors[c - 39])
            elseif c > 89 and c < 98 then
              self.surface:fg(colors[c - 89])
            elseif c > 99 and c < 108 then
              self.surface:bg(colors[c - 99])
            elseif c == 39 then
              self.surface:fg(colors.lightGray)
            elseif c == 49 then
              self.surface:fg(colors.black)
            end
          end
        end
        corral(self)
      elseif css == "?" then
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
