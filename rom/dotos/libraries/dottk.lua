-- .TK: the DoT OS UI toolkit v2 --

local settings = require("settings")
local colors = dofile("/dotos/resources/dottk/colors."..
  (settings.sysget("dotTkColors") or "default")..".lua")
local sigtypes = require("sigtypes")
local surface = require("surface")
local textutils = require("textutils")

colors.titlebar_text = colors.titlebar_text or colors.text_color
colors.button_color = colors.button_color or colors.accent_color
colors.titlebar = colors.titlebar_color or colors.base_color

local _element = {}

function _element:new(args)
  local new = setmetatable({}, {__index = self})
  if new.init then
    checkArg(1, args, "table")
    new:init(args)
  end
  return new
end

function _element:inherit()
  local new = setmetatable({}, {__index = self})
  return new
end

-- all elements must have these functions
-- :draw() - takes an X offset and a Y offset, and draws
-- the element accordingly.
function _element:draw(x, y) end

-- :handle() - takes a signal ID, an X coordinate, and a
-- Y coordinate, both relative to the element's position
-- in the window so the element itself does not need to
-- do any special handling.  if the element can handle
-- that signal, then returns itself; otherwise, returns the
-- first non-nil result of calling `:handle()` with the same
-- signal ID on all of its children.
--
-- the X and Y coordinates are OPTIONAL, and only present
-- for some signal types.
function _element:handle(sig, x, y) end

-- :resize() - takes a width and a height, and resizes
-- the element accordingly.
function _element:resize() end

local tk = {}

-- generic element
tk.Element = _element:inherit()

tk.Window = tk.Element:inherit()
function tk.Window:init(args)
  checkArg("w", args.w, "number")
  checkArg("h", args.h, "number")
  checkArg("root", args.root, "table")
  self.w = args.w
  self.h = args.h
  self.root = args.root
  self.surface = surface.new(args.w, args.h)
  self.children = {}
  self.root:addWindow(self)
end

function tk.Window:draw(x, y)
  -- draw self
  self.surface:fill(x, y, self.w, self.h, " ", 1, self.bg)
  -- draw all elements
  for k, v in pairs(self.children) do
    v:draw(x + v.x - 1, y + v.y - 1)
  end
end

function tk.Window:resize(w, h)
  checkArg(1, w, "number")
  checkArg(2, h, "number")
  local oldW, oldH = self.w, self.h
  for k, v in pairs(self.children) do
    if v.resize then
      v:resize(v.w + (w - oldW), v.h + (h - oldH))
    end
  end
  self.surface:resize(w, h)
  self.w, self.h = w, h
end

function tk.Window:handle(sig, x, y)
  -- check children
  if x and y then
    for i, c in ipairs(self.children) do
      if x >= c.x and y >= c.y and x < c.x + c.w and y < c.y + c.h then
        local nel = c:handle(sig, x - c.x + 1, y - c.y + 1)
        self.focused = nel or self.focused
        if nel then return nel end
      end
    end
  elseif self.focused then
    self.focused:handle(sig)
  end
end

-- View: scrollable view of an item
-- this can have scrollbars attached, and is a container for an
-- arbitrarily sized element.  it is probably a good idea for
-- this element to only ever be a layout element item such as a
-- grid.
--
-- this element's initialization process is a little nonstandard:
-- you have to create its child element with the original parent
-- window, and *then* create a View element with its 'child'
-- field set to that child element.  the View element initializer
-- will unparent that child from its parent window and reparent
-- it to the View element's drawing surface.
tk.View = tk.Element:inherit()
function tk.View:init(args)
  checkArg(1, args, "table")
  checkArg("window", args.window, "table")
  checkArg("w", args.w, "number")
  checkArg("h", args.h, "number")
  checkArg("child", args.child, "table")

  self.window = args.window
  self.surface = args.window.surface
  self.buffer = surface.new(args.w, args.h)
  self.x = 1
  self.y = 1
  self.w = args.w
  self.h = args.h
  self.xscrollv = 0
  self.yscrollv = 0
  self.child = args.child
  -- the child element of this should *not* be a child of the
  -- parent window, so remove it from the parent window
  self.child.window.children[self.child.childid] = nil
  self.child.surface = surface.new(self.child.w, self.child.h)

  self.childid = #args.window.children+1
  args.window.children[self.childid] = self
end

function tk.View:xscroll(n)
  checkArg(1, n, "number")
  self.xscrollv = math.max(0, math.min(self.child.w - self.w))
end

function tk.View:yscroll(n)
  checkArg(1, n, "number")
  self.yscrollv = math.max(0, math.min(self.child.h - self.h))
end

function tk.View:draw(x, y)
  self.child:draw(1, 1)
  self.child.surface:blit(self.buffer, 1 - self.xscrollv, 1 - self.yscrollv)
  self.buffer:blit(self.surface, x, y)
end

function tk.View:handle(sig, x, y)
  if x and y then x, y = x - self.xscrollv, y - self.yscrollv end
  return self.child:handle(sig, x, y)
end

-- Grid: layout engine element
-- i may add more layouts in the future, but for now just a
-- grid is sufficient.  this will dynamically resize all its
-- child elements when it is resized, according to the number
-- of rows and columns it is configured to have.
tk.Grid = tk.Element:inherit()
function tk.Grid:init(args)
  checkArg(1, args, "table")
  checkArg("window", args.window, "table")
  checkArg("w", args.w, "number", "nil")
  checkArg("h", args.h, "number", "nil")
  local window = args.window
  self.window = window
  local surface = window.surface
  self.x = 1
  self.y = 1
  self.w = args.w or window.w
  self.h = args.h or window.h
  self.rows = 0
  self.colums = 0
  self.children = {}
  self.rheight = math.floor(self.h / self.rows)
  self.cwidth = math.floor(self.w / self.columns)
  self.childid = #window.children+1
  window.children[self.childid] = self
end

function tk.Grid:addChild(row, col, element)
  checkArg(1, row, "number")
  checkArg(2, col, "number")
  checkArg(3, element, "table")
  if row < 1 or row > self.rows then
    error("bad argument #1 (invalid row)") end
  if col < 1 or col > self.columns then
    error("bad argument #2 (invalid column)") end
  self.children[row] = self.children[row] or {}
  self.children[row][col] = element
end

function tk.Grid:draw(x, y)
  for r, row in ipairs(self.children) do
    for c, col in ipairs(row) do
      local cw, ch = col.w, col.h
      col:resize(math.min(self.width, col.w) math.min(self.rheight, col.h))
      col:draw(x + self.cwidth * (c-1), y + self.rheight * (r-1))
    end
  end
end

function tk.Grid:resize(w, h)
  checkArg(1, w, "number")
  checkArg(2, h, "number")
  self.w = w
  self.h = h
  self.rheight = math.floor(self.h / self.rows)
  self.cwidth = math.floor(self.w / self.columns)
  for r, row in ipairs(self.children) do
    for c, col in ipairs(row) do
      col.w = math.floor(self.w / self.columns)
      col.h = math.floor(self.h / self.rows)
    end
  end
end

function tk.Grid:handle(sig, x, y)
  if x and y then
    for r, row in ipairs(self.children) do
      for c, col in ipairs(row) do
        if x >= self.cwidth * (c-1) and y >= self.rheight * (r-1) and
           x < self.cwidth * c and y < self.rheight * r then
        return col:handle(sig, x - self.cwidth * (c-1),
          y - self.rheight * (r-1))
      end
    end
  end
end

tk.Text = tk.Element:inherit()
function tk.Text:init(args)
  checkArg(1, args, "table")
  checkArg("window", args.window, "table")
  checkArg("text", args.text, "string")
  self.window = args.window
  self.text = args.text
end

function tk.Text:resize(w, h)
  checkArg(1, w, "number")
  checkArg(2, h, "number")
  self.w = w
  self.h = h
end

-- TODO: properly handle ctrl-C (copy) and text selection
function tk.Text:handle(sig, x, y)
  return nil
end

function tk.Text:draw(x, y)
  -- word-wrap
  self.lines = textutils.wordwrap(self.text, self.w)
  for i, line in ipairs(self.lines) do
    if i > self.h then break end
    self.window.surface:set(1, i, textutils.padRight(line, self.w),
      colors.text_color, colors.base_color)
  end
end

return tk
