-- rewritten .ui parser --

local term = require("term")
local split = require("splitters").complex
local colors = require("colors")
local surface = require("dotui.surface")
local sigtype = require("sigtypes")

local ui = {}

local _app = {}

function _app:resize(w, h)
  self.surface:resize(w, h)
end

-- do WIDTH/HEIGHT/TWIDTH/THEIGHT replacements dynamically
local function procforwh(app, _em)
  local w, h = term.getSize()
  em = setmetatable({}, {__index = _em})
  if em.w == "TWIDTH" then em.w = w end
  if em.h == "THEIGHT" then em.h = h end
  if em.w == "WIDTH" then em.w = app.surface.w end
  if em.h == "HEIGHT" then em.h = app.surface.h end
  return em
end

local draw
draw = function(elements, xo, yo)
  xo = xo or 1
  yo = yo or 1
  for i=1, #elements, 1 do
    elements[i].draw(procforwh(elements[i]), xo, yo)
    -- support nesting
    if elements[i].elements then draw(elements[i].elements,
      elements[i].x, elements[i].y) end
  end
end

function _app:drawPage(name)
  checkArg(1, name, "string")
  if not self.pages[name] then
    error("no such page " .. name)
  end
  local page = self.pages[name]
  self.surface:fill(1, 1, self.surface.w, self.surface.h, page.background)
  draw(page.elements)
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
  if not self.app.callbacks[args.action] then
    error("bad callback " .. args.action)
  end
  self.elements[#self.elements+1] = {
    x = args.x, y = args.y,
    w = #args.text, h = 1, disabled = not not args.disabled,
    draw = function(s)
      self.app.surface:set(args.x, args.y, args.text, args.textcolor,
      args.color)
    end, click = self.app.callbacks[args.action]
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
      self.app:drawPage(name)
    end
  }
end

function ui.newApp(callbacks)
  local app = setmetatable({
    page = false,
    pages = {},
    callbacks = callbacks,
    surface = surface.new(1, 1, 1, 1)
  }, {__index = _app, __metatable = {}})
  app.surface:fg(colors.black):bg(colors.black)
  return app
end

function ui.newPage()
  local page = setmetatable({
    x = 1, y = 1, w = 1, h = 1,
    elements = {},
  }, {__index = _page, __metatable = {}})
  return page
end

local kv_pattern = "(.-)=(.+)"

local function coerce(item)
  if item:sub(1,1) == '"' then
    item = item:sub(2,-2)
  end
  if item == "true" or item == "false" then
    return item == "true"
  elseif item == "nil" then
    return nil
  end
  return tonumber(item) or item
end

local function eval(app, page, line)
  line = line:gsub("^ +", "")
  if line:sub(1,2) == "//" then return end
  local words = split(line)
  local method, args = words[1], {}
  for i=2, #words, 1 do
    local k, v = words[i]:match(kv_pattern)
    if k and v then
      v = coerce(v)
      args[k] = v
    else
      args[#args+1] = words[i]
    end
  end
  if not page[method] then
    error("undefined .ui method " .. method)
  end
  page[method](page, args)
end

local page_pattern = "([^ \n]+) (%b{})"

function ui.load(file, callbacks, app)
  checkArg(1, file, "string")
  checkArg(2, callbacks, "table")

  local handle = assert(io.open(file, "r"))
  local data = handle:read("a")
  handle:close()
  
  local app = app or ui.newApp(callbacks)

  for pagename, lines in data:gmatch(page_pattern) do
    lines = lines:sub(2, -2)
    local page = ui.newPage(app)
    page.app = app
    app.pages[pagename] = page
    for line in lines:gmatch("[^\n]+") do
      eval(app, page, line)
    end
  end

  return app
end

function ui.loop(app)
  checkArg(1, app, "table")
  while true do
    app:drawPage(app.page)
    local sig = app.surface:receiveSignal()
    if sigtypes.mouse[sig[1]] then
    end
  end
end

return ui
