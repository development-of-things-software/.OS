-- .TK: the DoT OS UI toolkit v2 --

local settings = require("settings")
local colors = dofile("/dotos/resources/dottk/colors."..
  (settings.sysget("dotTkColors") or "default")..".lua")
local sigtypes = require("sigtypes")

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
-- :draw() - takes a surface, an X offset, and a Y offset,
-- and draws the element accordingly
function _element:draw(surf, x, y) end

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

local tk = {}

-- generic element
tk.Element = _element:inherit()

tk.Window = tk.Element:inherit()
function tk.Window:init(args)
  checkArg("w", args.w, "number")
  checkArg("h", args.h, "number")
  checkArg("surface", args.surface, "table")
  self.w = args.w
  self.h = args.h
  self.surf = args.surface
  self.children = {}
end

function tk.Window:draw(x, y)
  -- draw all standard elements
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
  -- then check children
  for i, c in ipairs(self.children) do
    if x and y then
    end
  end
end

return tk
