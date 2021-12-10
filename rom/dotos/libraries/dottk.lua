-- .TK: the DoT OS UI toolkit v2 --

local settings = require("settings")
local colors = dofile("/dotos/resources/dottk/colors."..
  (settings.sysget("dotTkColors") or "default")..".lua")
local sigtypes = require("sigtypes")
local surface = require("surface")

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

-- the following functions are optional
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
        self.focused = c:handle(sig, x - c.x + 1, y - c.y + 1) or self.focused
      end
    end
  elseif self.focused then
    self.focused:handle(sig)
  end
end

return tk
