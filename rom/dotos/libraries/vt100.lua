-- VT100 layer over top of a surface --

local dotos = require("dotos")
local textutils = require("textutils")
local colors = require("colors")
local keys = require("keys")

assert(colors.loadPalette("vga"))

local vtc = {
  -- standard 8 colors
  colors.black,
  colors.red,
  colors.green,
  colors.yellow,
  colors.blue,
  colors.purple,
  colors.cyan,
  colors.lightGray,
  -- "bright" colors
  colors.darkGray,
  colors.lightRed,
  colors.lightGreen,
  colors.lightYellow,
  colors.lightBlue,
  colors.lightPurple,
  colors.lightCyan,
  colors.white
}

local lib = {}

local vts = {}

local function corral(s)
  while s.cx < 1 do
    s.cy = s.cy - 1
    s.cx = s.cx + s.surface.w
  end

  while s.cx > s.surface.w do
    s.cy = s.cy + 1
    s.cx = s.cx - s.surface.w
  end
  
  while s.cy < 1 do
    s:scroll(-1)
    s.cy = s.cy + 1
  end

  while s.cy >= s.surface.h do
    s:scroll(1)
    s.cy = s.cy - 1
  end
end

function vts:scroll(n)
  if n > 0 then
    for i=n+1, self.surface.h, 1 do
      self.surface.buffer_text[i - n] = self.surface.buffer_text[i]
      self.surface.buffer_fg[i - n] = self.surface.buffer_fg[i]
      self.surface.buffer_bg[i - n] = self.surface.buffer_bg[i]
    end
    self.surface:fill(1, self.surface.h - n, self.surface.w, n, " ")
  elseif n < 0 then
    for i=self.surface.h - n, 1, -1 do
      self.surface.buffer_text[i - n] = self.surface.buffer_text[i]
      self.surface.buffer_fg[i - n] = self.surface.buffer_fg[i]
      self.surface.buffer_bg[i - n] = self.surface.buffer_bg[i]
    end
    self.surface:fill(1, 1, self.surface.w, n, " ")
  end
end

function vts:raw_write(str)
  checkArg(1, str, "string")
  while #str > 0 do
    local nl = str:find("\n") or #str
    local line = str:sub(1, nl)
    str = str:sub(#line + 1)
    local nnl = line:sub(-1) == "\n"
    while #line > 0 do
      local chunk = line:sub(1, self.surface.w - self.cx + 1)
      line = line:sub(#chunk + 1)
      self.surface:set(self.cx, self.cy, chunk)
      self.cx = self.cx + #chunk
      corral(self)
    end
    if nnl and self.cx > 1 then
      self.cx = 1
      self.cy = self.cy + 1
    end
    corral(self)
  end
end

function vts:write(str)
  checkArg(1, str, "string")
  -- hide cursor
  local cc, cf, cb = self.surface:get(self.cx, self.cy, 1)
  self.surface:rawset(self.cx, self.cy, cc, cb, cf)
  while #str > 0 do
    local nesc = str:find("\27")
    local e = (nesc and nesc - 1) or #str
    local chunk = str:sub(1, e)
    str = str:sub(#chunk+1)
    self:raw_write(chunk)
    if nesc then
      local css, paramdata, csc, len
        = str:match("^\27([%[%?])([%d;]*)([%a%[])()")
      str = str:sub(len)
      local args = {}
      for n in paramdata:gmatch("[^;]+") do
        args[#args+1] = tonumber(n)
      end
      if css == "[" then
        -- minimal subset of the standard
        if csc == "[" then
          self:raw_write("^[[")
        elseif csc == "A" then
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
          self.cy = math.max(1, math.min(self.surface.h-1, args[1]))
          self.cx = math.max(1, math.min(self.surface.w, args[2]))
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
              self.echo = true
            elseif c == 8 then
              self.echo = false
            elseif c == 28 then
              self.echo = true
            elseif c > 29 and c < 38 then
              self.surface:fg(2^(c-30))--vtc[c - 29])
            elseif c > 39 and c < 48 then
              self.surface:bg(2^(c-40))--vtc[c - 39])
            elseif c > 89 and c < 98 then
              self.surface:fg(2^(c-82))--vtc[c - 81])
            elseif c > 99 and c < 108 then
              self.surface:bg(2^(c-92))--vtc[c - 91])
            elseif c == 39 then
              self.surface:fg(colors.lightGray)
            elseif c == 49 then
              self.surface:bg(colors.black)
            end
          end
        elseif csc == "n" then
          if args[1] == 6 then
            self.ibuf = self.ibuf .. string.format("\27[%d;%dR",
              self.cy, self.cx)
          end
        elseif csc == "S" then
          self:scroll(args[1] or 1)
        elseif csc == "T" then
          self:scroll(-(args[1] or 1))
        end
        corral(self)
      elseif css == "?" then
        if csc == "c" then
          args[1] = args[1] or 0
          for _, n in ipairs(args) do
            if n == 0 then
              self.echo = true
              self.line = true
              self.raw = false
            elseif n == 1 then
              self.echo = true
            elseif n == 2 then
              self.line = true
            elseif n == 3 then
              self.raw = true
            elseif n == 11 then
              self.echo = false
            elseif n == 12 then
              self.line = false
            elseif n == 13 then
              self.raw = false
            end
          end
        end
      end
    else
      break
    end
  end
  -- show cursor
  local ccc, ccf, ccb = self.surface:get(self.cx, self.cy, 1)
  self.surface:rawset(self.cx, self.cy, ccc, ccb, ccf)
end

function vts:readc()
  while #self.ibuf == 0 do coroutine.yield() end
  local byte = self.ibuf:sub(1,1)
  self.ibuf = self.ibuf:sub(2)
  return byte
end

function vts:readline(knl)
  checkArg(1, knl, "boolean", "nil")
  while not self.ibuf:match("\n") do coroutine.yield() end
  local n = self.ibuf:find("\n")
  local ln = self.ibuf:sub(1, n)
  self.ibuf = self.ibuf:sub(#ln + 1)
  if not knl then ln = ln:sub(1, -2) end
  return ln
end

function vts:read(n)
  checkArg(1, n, "number")
  local ret = ""
  if self.line and not self.raw then
    while not self.ibuf:match("\n") do coroutine.yield() end
  end
  repeat
    local c = self:readc()
    ret = ret .. c
  until #ret == n or ((not self.raw) and c == "\4")
  if ret:sub(-1) == "\4" and not self.raw then
    ret = ret:sub(1, -2)
    if #ret == 0 then return nil end
  end
  return ret
end

function vts:close()
  dotos.drop(self.specialhandler)
  dotos.drop(self.charhandler)
  dotos.drop(self.resizehandler)
end

function lib.new(surf)
  checkArg(1, surf, "table")
  surf:fg(colors.lightGray)
  surf:bg(colors.black)
  surf:fill(1, 1, surf.w, surf.h, " ")
  local new
  new = setmetatable({
    cx = 1, cy = 1, ibuf = "", echo = true,
    surface = surf, specialhandler = dotos.handle("key", function(_, k)
      if k == keys.backspace then
        if new.raw then
          new.ibuf = new.ibuf .. "\8"
        else
          if #new.ibuf > 0 and new.ibuf:sub(-1) ~= "\n" then
            new.ibuf = new.ibuf:sub(1, -2)
            if new.echo then new:write("\27[D \27[D") end
          end
        end
      elseif k == keys.enter then
        if new.raw then
          new.ibuf = new.ibuf .. "\r"
        else
          if new.echo then new:write("\n") end
          new.ibuf = new.ibuf .. "\n"
        end
      elseif k == keys.up then
        if new.echo and not new.raw then new:write("\27[[A") end
        new.ibuf = new.ibuf .. "\27[A"
      elseif k == keys.down then
        if new.echo and not new.raw then new:write("\27[[B") end
        new.ibuf = new.ibuf .. "\27[B"
      elseif k == keys.left then
        if new.echo and not new.raw then new:write("\27[[D") end
        new.ibuf = new.ibuf .. "\27[D"
      elseif k == keys.right then
        if new.echo and not new.raw then new:write("\27[[C") end
        new.ibuf = new.ibuf .. "\27[C"
      elseif keys.ctrlPressed() and #keys[k] == 1 then
        local byte = string.byte(keys[k])
        if byte > 96 and byte < 123 then
          new.ibuf = new.ibuf .. string.char(byte - 96)
        end
      end
    end), charhandler = dotos.handle("char", function(_, c)
      if new.echo then new:write(c) end
      new.ibuf = new.ibuf .. c
    end), resizehandler = dotos.handle("term_resize", function()
      if new.term then
        local nw, nh = new.term.getSize()
        new.surface:resize(nw, nh + 1)
        new.cy = math.min(new.cy, nh)
      end
    end)
  }, {__index = vts, __metatable = {}})
  return new
end

return lib
