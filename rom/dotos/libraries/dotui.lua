-- .UI --

local textutils = require("textutils")
local colors = require("colors")
local lerp = require("advmath").lerp
local surf = require("surface")
local term = require("term")

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
  if self.hidden then return end
  if self.clickable then
    return self
  else
    for k, child in ipairs(self.children) do
      if x >= child.x and y >= child.y and x <= child.x + child.w - 1 and
          y <= child.x + child.h - 1 then
        local f = child:find(x - child.x + 1, y - child.y + 1)
        if f then return f end
      end
    end
  end
end

function element:addChild(child)
  local n = #self.children+1
  self.children[n] = child
  child.surface = child.surface or self.surface
  return n
end

local function computeCoordinates(self, xoff, yoff)
  xoff = xoff or 0
  yoff = yoff or 0
  return
    self.x + xoff,
    self.y + yoff,
    self.w, self.h
    --math.ceil(self.x * self.surface.w) + xoff,
    --math.ceil(self.y * self.surface.h) + yoff,
    --math.ceil(self.w * self.surface.w),
    --math.ceil(self.h * self.surface.h)
end

function element:draw(xoff, yoff)
  if self.hidden then return end
  local x, y, w, h = computeCoordinates(self, xoff, yoff)
  self.surface:fill(x, y, w, h, " ", self.fcolor, self.bcolor)
  if self.text then
    local text
    if self.wrap then
      text = textutils.wordwrap(self.text, w, h)
    else
      text = {self.text:sub(1, w)}
    end
    for i=1, #text, 1 do
      self.surface:set(x, y+i-1, text[i], self.fg, self.bg)
    end
  end
  for k, v in pairs(self.children) do
    v:draw(self.x - 1, self.y - 1)
  end
end

local function base_init(self, args, needsText)
  checkArg(1, args, "table")
  checkArg("x", args.x, "number")
  checkArg("y", args.y, "number")
  checkArg("w", args.w, "number")
  checkArg("h", args.h, "number")
  checkArg("fg", args.fg, "number")
  checkArg("bg", args.bg, "number")
  if needsText then
    checkArg("text", args.text, "string")
  else
    checkArg("text", args.text, "string", "nil")
  end
  -- X, Y, width, and height are 0..1 and proportional to the surface
  -- this allows much easier scaling
  self.x = args.x
  self.y = args.y
  self.w = args.w
  self.h = args.h
  self.text = args.text
  self.wrap = not not args.wrap
  self.fcolor = args.fg
  self.bcolor = args.bg
  self.surface = args.surface or self.surface
end

local lib = {}

lib.UIElement = element:new()
lib.UIPage = lib.UIElement:new()

function lib.UIPage:init(args)
  checkArg(1, args, "table")
  base_init(self, args)
end

lib.Scrollable = lib.UIElement:new()
function lib.Scrollable:init(args)
  base_init(self, args)
  checkArg(1, args.child, "table")
  self.scrollX = 0
  self.scrollY = 0
  self.child = args.child
end

function lib.Scrollable:draw(xoff, yoff)
  -- render child
  self.child:draw()
  -- blit surface
  local x, y, w, h = computeCoordinates(self, xoff, yoff)
  self.child.surface:blit(self.surface, x, y, self.scrollX, self.scrollY)
end

function lib.Scrollable:find(x, y)
  return self.child:find(x + self.scrollX,
    y + self.scrollY)
end

lib.Label = lib.UIElement:new()
function lib.Label:init(args)
  base_init(self, args, true)
end

lib.Clickable = lib.UIElement:new()
function lib.Clickable:init(args)
  base_init(self, args)
  checkArg("callback", args.callback, "function")
  self.clickable = true
  self.callback = args.callback
end

lib.Switch = lib.UIElement:new()
function lib.Switch:init(args)
  checkArg(1, args, "table")
  function args.callback(self)
    self.state = not self.state
    self.switched = os.epoch("utc")
  end
  lib.Clickable.init(self, args)
  checkArg("activatedColor", args.activatedColor, "number")
  self.activatedColor = args.activatedColor
end

function lib.Switch:draw(xoff, yoff)
  local x, y, w, h = computeCoordinates(self, xoff, yoff)
  self.surface:fill(x, y, w, h, " ", self.fcolor,
    self.state and self.activatedColor or self.bcolor)
  local knobWidth = math.ceil(w / 10)
  if self.state then
    self.surface:fill(x, y, knobWidth, self.h, " ",
      self.bcolor, self.fcolor)
  else
    self.surface.fill(x + w - knobWidth, y, w, h, " ",
      self.bcolor, self.fcolor)
  end
end

-- window management
lib.window = {}

local windows = {}

function lib.window.getWindowTable()
  lib.window.getWindowTable = nil
  return windows
end

local window = {}

function window:sendSignal(sig)
  self.queue[#self.queue+1] = sig
  return true
end

function window:receiveSignal()
  while #self.queue == 0 do coroutine.yield() end
  return table.remove(self.queue, 1)
end

function window:pollSignal()
  return table.remove(self.queue, 1)
end

-- returns the created window
function lib.window.register(x, y, surface)
  local win = setmetatable({x=x, y=y, w=surface.w, h=surface.h,
    buffer=surface, queue={}}, {__index=window})
  table.insert(windows, 1, win)
  return win
end

-- returns the created surface and window
function lib.window.create(x, y, w, h)
  checkArg(1, x, "number")
  checkArg(2, y, "number")
  checkArg(3, w, "number")
  checkArg(4, h, "number")
  local tw, th = term.getSize()
  if w <= 1 and h <= 1 then
    w, h = math.floor(w * tw + 0.5), math.floor(w * th + 0.5)
  end
  local surface = surf.new(w, h)
  return surface, lib.window.register(x, y, surface)
end

-- common utilities
lib.util = {}

function lib.util.basicWindow(x, y, w, h, title)
  checkArg(1, x, "number")
  checkArg(2, y, "number")
  checkArg(3, w, "number")
  checkArg(4, h, "number")
  checkArg(5, title, "string", "nil")
  title = title or "New Window"
  if #title > (w - 2) then title = title:sub(w - 5) .. "..." end
  local surface, window = lib.window.create(x, y, w, h)
  local winbase = lib.UIPage:new {
    x = 1, y = 1, w = surface.w, h = surface.h,
    fg = colors.black, bg = colors.black, surface = surface
  }
  local titlebar = lib.UIPage:new {
    x = 1, y = 1, w = surface.w, h = 1,
    fg = colors.white, bg = colors.gray, text = title
  }
  local close = lib.Clickable:new {
    x = surface.w, y = 1, w = 1, h = 1, text = "X",
    fg = colors.black, bg = colors.lightGray, callback = function()
      window.delete = true
    end
  }
  local body = lib.UIPage:new {
    x = 1, y = 2, w = surface.w, h = surface.h - 1,
    fg = colors.black, bg = colors.white
  }
  winbase:addChild(titlebar)
  titlebar:addChild(close)
  winbase:addChild(body)
  return winbase, body, surface, window
end

function lib.util.prompt(text, opts)
  checkArg(1, text, "string")
  checkArg(2, opts, "table")
  local wb, base, surface, window = lib.util.basicWindow(5, 4, 16, 5)
  local result = ""
  base:addChild(lib.Label:new {
    x = 2, y = 1, w = surface.w - 2, h = surface.h - 1,
    text = text, fg = colors.black, bg = colors.white, wrap = true
  })
  local x = surface.w
  for i=#opts, 1, -1 do
    x = x - #opts[i] - 1
    base:addChild(lib.Clickable:new {
      x = x, y = 4, w = #opts[i], h = 1,
      fg = colors.black, bg = colors.lightGray, callback = function()
        result = opts[i]
        window.delete = true
        os.reboot()
      end, text = opts[i]
    })
  end
  local lastWasDrag
  while not window.delete do
    wb:draw()
    local sig = window:receiveSignal()
    if sig[1] == "mouse_click" then
      local element = wb:find(sig[3], sig[4])
      if element then
        element:callback()
      end
    elseif sig[1] == "mouse_drag" then
      window.dragging = lastWasDrag
    elseif sig[1] == "mouse_up" then
      window.dragging = false
    end
    lastWasDrag = sig[1] == "mouse_drag"
  end
  return result
end

return lib
