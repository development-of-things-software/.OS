-- This API is similar to the Window api provided by CraftOS, but:
--   - it does not attempt to provide an API similar to term,
--     instead preferring a custom set of commands
--   - it uses proper object-orientation rather than...
--     whatever it is the Window api does

local term = require("term")
local colors = require("colors")

local s = {}

local function into_buffer(buf, x, y, text, xoff)
  if not text then return end
  if not buf[y] then return end
  xoff = xoff or 0
  text = text:sub(xoff + 1)
  text = text:sub(1, #buf[y] - x + 1)
  if x < 1 then
    text = text:sub(-x)
  end
  local olen = #buf[y]
  buf[y] = (buf[y]:sub(0, math.max(0,x-1)) .. text .. buf[y]:sub(x + #text))
    :sub(1, olen)
end

function s:blit(parent, x, y, xoff, yoff)
  checkArg(1, parent, "table")
  checkArg(2, x, "number")
  checkArg(3, y, "number")
  checkArg(4, xoff, "number", "nil")
  checkArg(5, yoff, "number", "nil")
  xoff = xoff or 0
  yoff = yoff or 0
  for i=1, self.h, 1 do
    into_buffer(parent.buffer_fg, x, y + i - 1,
      self.buffer_fg[i + yoff], xoff)
    into_buffer(parent.buffer_bg, x, y + i - 1,
      self.buffer_bg[i + yoff], xoff)
    into_buffer(parent.buffer_text, x, y + i - 1,
      self.buffer_text[i + yoff], xoff)
  end
  return self
end

function s:draw(x, y)
  checkArg(1, x, "number")
  checkArg(2, y, "number")
  for i=1, self.h, 1 do
    term.setCursorPos(x, y + i - 1)
    term.blit(self.buffer_text[i], self.buffer_fg[i], self.buffer_bg[i])
  end
  return self
end

function s:fill(x, y, w, h, ch, fg, bg)
  checkArg(1, x, "number")
  checkArg(2, y, "number")
  checkArg(3, w, "number")
  checkArg(4, h, "number")
  checkArg(5, ch, "string", "nil")
  checkArg(6, fg, "number", self.foreground and "nil")
  checkArg(7, bg, "number", self.background and "nil")
  if w == 0 or h == 0 then return self end
  self.foreground = fg or self.foreground
  self.background = bg or self.background
  ch = (ch or " "):sub(1,1):rep(w)
  fg = colors.toBlit(self.foreground):rep(w)
  bg = colors.toBlit(self.background):rep(w)
  for i=1, h, 1 do
    into_buffer(self.buffer_text, x, y + i - 1, ch)
    into_buffer(self.buffer_fg, x, y + i - 1, fg)
    into_buffer(self.buffer_bg, x, y + i - 1, bg)
  end
  return self
end

function s:set(x, y, str, fg, bg)
  checkArg(1, x, "number")
  checkArg(2, y, "number")
  checkArg(3, str, "string")
  checkArg(4, fg, "number", self.foreground and "nil")
  checkArg(5, bg, "number", self.background and "nil")
  if #str == 0 then return self end
  self.foreground = fg or self.foreground
  self.background = bg or self.background
  fg = colors.toBlit(fg or self.foreground):rep(#str)
  bg = colors.toBlit(bg or self.background):rep(#str)
  into_buffer(self.buffer_text, x, y, str)
  into_buffer(self.buffer_fg, x, y, fg)
  into_buffer(self.buffer_bg, x, y, bg)
  return self
end

function s:rawset(x, y, str, fg, bg)
  checkArg(1, x, "number")
  checkArg(2, y, "number")
  checkArg(3, str, "string")
  checkArg(4, fg, "string")
  checkArg(5, bg, "string")
  assert(#str == #fg and #str == #bg, "mismatched argument lengths")
  into_buffer(self.buffer_text, x, y, str)
  into_buffer(self.buffer_fg, x, y, fg)
  into_buffer(self.buffer_bg, x, y, bg)
  return self
end

function s:get(x, y, len)
  checkArg(1, x, "number")
  checkArg(2, y, "number")
  checkArg(3, len, "number")
  local text = self.buffer_text[y]:sub(x, x + len - 1)
  local fg = self.buffer_fg[y]:sub(x, x + len - 1)
  local bg = self.buffer_bg[y]:sub(x, x + len - 1)
  return text, fg, bg
end

function s:fg(col)
  checkArg(1, col, "number", "nil")
  if col then self.foreground = col return self end
  return self.foreground
end

function s:bg(col)
  checkArg(1, col, "number", "nil")
  if col then self.background = col return self end
  return self.background
end

local function expand_buffer(self, buf, nw, nh)
  if nh > self.h then
    for i=1, nh - self.h, 1 do
      buf[#buf+1] = buf[#buf]
    end
  end
  if nw > self.w then
    for i=1, #buf, 1 do
      buf[i] = buf[i] .. buf[i]:sub(-1):rep(nw - self.w)
    end
  end
end

function s:resize(w, h)
  checkArg(1, w, "number")
  checkArg(2, h, "number")
  expand_buffer(self, self.buffer_text, w, h)
  expand_buffer(self, self.buffer_fg, w, h)
  expand_buffer(self, self.buffer_bg, w, h)
  self.w = w
  self.h = h
end

local surf = {}

function surf.new(w, h)
  checkArg(1, w, "number")
  checkArg(2, h, "number")
  local new = setmetatable({
    buffer_fg = {},
    buffer_bg = {},
    buffer_text = {},
    w = w, h = h
  }, {__index = s, __metatable = {}})
  local zero = string.rep("0", w)
  local blank = string.rep(" ", w)
  for i=1, h, 1 do
    new.buffer_fg[i] = zero
    new.buffer_bg[i] = zero
    new.buffer_text[i] = blank
  end
  return new
end

return surf
