-- .UI --

local text = require("text")

local function new(self, ...)
  local new = setmetatable({}, {__index = self, __metatable = {}})
  new.children = {}
  if new.init then
    new:init(...)
  end
  new.surface = new.surface or self.surface
  return new
end

local element = {}
element.new = new
function element:find(x, y)
  if self.clickable then
    return self
  else
    for k, child in ipairs(self.children) do
      if x >= child.x and y >= child.y and x <= child.x + child.w and
          y <= child.x + child.h then
        return child:find(x, y)
      end
    end
  end
end

function element:addChild(chld)
  local n = #self.children+1
  self.children[n] = chld
  return n
end

function element:draw(xoff, yoff)
  xoff = xoff or 0
  yoff = yoff or 0
end

local function base_init(self, args, needsText)
  checkArg(1, args, "table")
  checkArg("x", args.x, "number")
  checkArg("y", args.y, "number")
  checkArg("w", args.w, "number")
  checkArg("h", args.h, "number")
  if needsText then
    checkArg("text", args.text, "string")
  else
    checkArg("text", args.text, "string", "nil")
  end
  if args.text then
    if args.wrap then
      args.text = text.wrap(args.text, args.w, args.h)
    else
      args.text = args.text:sub(1, args.w)
    end
  end
end

local lib = {}

lib.UIElement = element:new()
lib.Label = lib.UIElement:new()
function lib.Label:init(args)
  base_init(self, args, true)
end

lib.Clickable = lib.UIElement:new()
function lib.Clickable:init(args)
  base_init(self, args)
  self.clickable = true
end

return lib
