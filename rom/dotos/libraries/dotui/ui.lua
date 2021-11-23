-- rewritten .ui parser --

local split = require("splitters").complex
local surface = require("dotui.surface")

local ui = {}

local _app = {}

function _app:resize()
end

local draw
draw = function(elements)
  for i=1, #elements, 1 do
    elements[i]:draw()
  end
end

function _app:drawPage(name)
  checkArg(1, name, "string")
  if not self.pages[name] then
    error("no such page " .. name)
  end
  local page = self.pages[name]
  draw(page)
end

local _page = {}

function _page:surface(args)
  self.x = args.x
  self.y = args.y
  self.w = args.w
  self.h = args.h
end

function _page:background(args)
  self.background = args.color
end

function _page:button(args)
  self.elements[#self.elements+1] = {
    x = args.x, y = args.y,
    w = #args.text, h = 1,
    draw = function(s)
      self.app.surface:set(s.x, s.y, args.text, args.textcolor, args.color)
    end
  }
end

function _page:show(args)
  local name = args[1]
  if not self.app.pages[name] then
    error("nonexistent page " .. name)
  end
  args.x = args.x or 1
  args.y = args.y or 1
  local page = self.app.pages[name]
  self.elements[#self.elements+1] = {
    x = args.x + page.x - 1,
    y = args.y + page.y - 1,
    w = page.w, h = page.h,
    elements = page.elements,
    draw = function(s)
      self.app:drawPage(s)
    end
  }
end

function ui.newApp(callbacks)
  local app = setmetatable({
    pages = {},
    callbacks = callbacks,
    surface = surface.new()
  }, {__index = _app, __metatable = {}})
  return app
end

function ui.newPage()
  local page = setmetatable({
    x = 1, y = 1, w = 1, h = 1,
    elements = {},
  }, {__index = _page, __metatable = {}})
  return page
end

local function eval(app, page, line)
end

local page_pattern = "([^ ]+) %b{}"

function ui.load(file, callbacks)
  checkArg(1, file, "string")
  checkArg(2, callbacks, "table")

  local handle = assert(io.open(file, "r"))
  local data = file:read("a")
  file:close()
  
  local app = ui.newApp(callbacks)
  for pagename, lines in data:gmatch(page_pattern) do
    local page = ui.newPage(app)
    page.app = app
    app.pages[pagename] = page
    for line in lines:gmatch("[^\n]+") do
      eval(app, page, line)
    end
  end
end

return ui
