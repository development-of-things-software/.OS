-- .UI --

local textutils = require("textutils")
local colors = require("colors")
local lerp = require("advmath").lerp
local surf = require("surface")
local term = require("term")
local sigtypes = require("sigtypes")
local colorscheme = require("dotui.colors")

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
function element:find(x, y, fscr)
  if self.hidden then return end
  if self.clickable and not fscr then
    return self
  else
    for k, child in ipairs(self.children) do
      if x >= child.x and y >= child.y and x <= child.x + child.w - 1 and
          y <= child.y + child.h - 1 then
        local f = child:find(x - child.x + 1, y - child.y + 1, fscr)
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
  local x, y, w, h = self.x, self.y, self.w, self.h
  if x < 1 then x = self.surface.w + x end
  if y < 1 then y = self.surface.h + y end
  return x + xoff, y + yoff, w, h
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
    for i=self.textScroll or 1, #text, 1 do
      self.surface:set(x, y+i-(self.textScroll or 1), text[i] or "",
        self.fg, self.bg)
    end
  end
  xoff = xoff or 0
  yoff = yoff or 0
  for k, v in pairs(self.children) do
    v.surface = v.surface or self.surface
    v:draw(xoff + self.x - 1, yoff + self.y - 1)
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
  args.fg = args.fg or colorscheme.textcol_default
  args.bg = args.bg or colorscheme.bg_default
  base_init(self, args)
end

lib.Scrollable = lib.UIElement:new()
function lib.Scrollable:init(args)
  if args then
    args.fg = args.fg or colorscheme.textcol_default
    args.bg = args.bg or colorscheme.bg_default
  end
  base_init(self, args)
  checkArg(1, args.child, "table")
  self.scrollX = 0
  self.scrollY = 0
  self.child = args.child
  self.child.surface = self.child.surface or
    surf.new(self.child.w, self.child.h)
end

function lib.Scrollable:draw(xoff, yoff)
  -- render child
  self.child:draw()
  -- blit surface
  local x, y, w, h = computeCoordinates(self, xoff, yoff)
  self.surface:fill(x, y, w, h, " ", self.fcolor, self.bcolor)
  self.child.surface:blit(self.surface, x - self.scrollX, y - self.scrollY)
end

function lib.Scrollable:find(x, y, fscr)
  local element = self.child:find(x + self.scrollX,
    y + self.scrollY, fscr)
  if fscr then element = element or self end
  return element
end

lib.Label = lib.UIElement:new()
function lib.Label:init(args)
  if args then
    args.fg = args.fg or colorscheme.textcol_default
    args.bg = args.bg or colorscheme.bg_default
  end
  base_init(self, args, true)
end

lib.Clickable = lib.UIElement:new()
function lib.Clickable:init(args)
  if args then
    args.fg = args.fg or colorscheme.clickable_text_default
    args.bg = args.bg or colorscheme.clickable_bg_default
  end
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
end

function lib.Switch:draw(xoff, yoff)
  local x, y, w, h = computeCoordinates(self, xoff, yoff)
  self.surface:fill(x, y, w, h, " ", self.fcolor,
    self.state and colorscheme.switch_on or colorscheme.switch_off)
  local knobWidth = math.ceil(w / 2)
  if self.state then
    self.surface:fill(x, y, knobWidth, self.h, " ",
      self.bcolor, self.fcolor)
  else
    self.surface.fill(x + w - knobWidth, y, w, h, " ",
      self.bcolor, self.fcolor)
  end
end

lib.Menu = lib.UIElement:new()
function lib.Menu:init(args)
  if args then
    args.fg = args.fg or colorscheme.menu_text_default
    args.bg = args.bg or colorscheme.menu_bg_default
  end
  base_init(self, args)
  self.items = 0
end

function lib.Menu:addItem(text, callback)
  checkArg(1, text, "string")
  checkArg(2, callback, "function")
  self.items = self.items + 1
  -- TODO: scrollable menus?
  if self.items > self.h then self.h = self.items end
  local obj = lib.Clickable:new {
    x = 1, y = self.items, w = self.surface.w, h = 1,
    text = text, callback = callback, fg = self.fcolor,
    bg = self.bcolor
  }
  self:addChild(obj)
  return obj
end

function lib.Menu:addSpacer()
  self.items = self.items + 1
  if self.items > self.h then self.h = self.items end
  local obj = lib.Label:new {
    x = 1, y = self.items, w = self.surface.w, h = 1,
    text = string.rep("\140", self.surface.w),
    fg = self.fcolor, bg = self.bcolor
  }
end

lib.Selector = lib.UIElement:new()
function lib.Selector:init(args)
  if args then
    args.fg = args.fg or colorscheme.textcol_default
    args.bg = args.bg or colorscheme.bg_default
  end
  base_init(self, args)
  self.selected = {}
  checkArg("items", args.items, "table", "nil")
  self.items = args.items or {}
  self.exclusive = not not args.exclusive
end

function lib.Selector:addItem(text)
  checkArg(1, text, "string")
  self.items[#self.items+1] = text
end

function lib.Selector:draw(xoff, yoff)
  local x, y, w, h = computeCoordinates(self, xoff, yoff)
  self.surface:fill(x, y, w, h, " ", self.fcolor, self.bcolor)
  for i=1, #self.items, 1 do
    if self.selected[i] then
      self.surface:set(x, y+i-1, "\7", colorscheme.selector_selected_fg,
        colorscheme.selector_selected_bg)
    else
      self.surface:set(x, y+i-1, "\7", colorscheme.selector_unselected_fg,
        colorscheme.selector_unselected_bg)
    end
    self.surface:set(x+2, y+i-1, self.items[i], self.fcolor, self.bcolor)
  end
end

function lib.Selector:find(x, y, fscr)
  checkArg(1, x, "number")
  checkArg(2, y, "number")
  if y > #self.items or fscr then return end
  if self.exclusive then self.selected = {} end
  self.selected[y] = not self.selected[y]
end

lib.Dropdown = lib.UIElement:new()
-- dropdown: selection menu hidden behind a button
function lib.Dropdown:init(args)
  checkArg(1, args, "table")
  checkArg("items", args.items, "table", "nil")
  args.fg = args.fg or colorscheme.dropdown_text_default
  args.bg = args.bg or colorscheme.dropdown_bg_default
  base_init(self, args)
  self.items = args.items or {}
  self.selected = args.selected or 0
  self.menuHidden = true
  self.button = 1
end

function lib.Dropdown:addItem(text)
  checkArg(1, text, "string")
  self.items[#self.items+1] = text
end

function lib.Dropdown:draw(xoff, yoff)
  local x, y, w, h = computeCoordinates(self, xoff, yoff)
  self.surface:set(x, y, textutils.padRight(self.text or "Select something",
    self.w - 2):sub(1, self.w - 2) .. " \31",
    self.fcolor, self.bcolor)
  if not self.menuHidden then
    for i=1, #self.items, 1 do
      local text = textutils.padRight(self.items[i], w)
      if i == self.selected then
        self.surface:set(x, y + i, text, colorscheme.selector_selected_fg,
          colorscheme.selector_selected_bg)
      else
        self.surface:set(x, y + i, text, self.fcolor, self.bcolor)
      end
    end
  end
end

function lib.Dropdown:find(x, y, fscr)
  if fscr then return end
  if y == 1 then
    self.menuHidden = not self.menuHidden
  elseif not self.menuHidden then
    self.selected = y - 1
    self.text = self.items[self.selected] or self.text
    self.menuHidden = true
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

function window:addPage(id, page)
  checkArg(1, id, "string")
  checkArg(2, page, "table")
  self.pages[id] = page
  if not self.page then self.page = id end
  if not page.surface then page.surface = self.buffer end
end

function window:drawPage(id)
  checkArg(1, id, "string")
  self.pages[id]:draw()
end

function window:setPage(id)
  checkArg(1, id, "string")
  self.page = id
end

function window:draw()
  self:drawPage(self.page)
  if self.pages.titlebar then self:drawPage("titlebar") end
end

function window:findInPage(name, x, y, fscr)
  checkArg(1, name, "string")
  checkArg(2, x, "number")
  checkArg(3, y, "number")
  return self.pages[name]:find(x - self.pages[name].x + 1,
    y - self.pages[name].y + 1, fscr)
end

function window:find(x, y, fscr)
  checkArg(1, x, "number")
  checkArg(2, y, "number")
  return self:findInPage(self.page, x, y, fscr) or
    self.pages.titlebar and self:findInPage("titlebar", x, y, fscr)
end

-- returns the created window
function lib.window.register(x, y, surface)
  local win = setmetatable({x=x, y=y, w=surface.w, h=surface.h,
    buffer=surface, queue={}, pages = {}, pid=dotos.getpid()},
    {__index=window})
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
  return lib.window.register(x, y, surface)
end

-- common utilities
lib.util = {}

function lib.util.loadApp(name, file)
  checkArg(1, name, "string")
  checkArg(2, file, "string")
  local ok, err = loadfile(file)
  if not ok then
    dotos.spawn(function()
      lib.util.prompt(file..": "..err, {"OK", title="Application Error"})
      dotos.exit()
    end, ".prompt")
    return nil
  end
  return dotos.spawn(ok, name)
end

function lib.util.basicWindow(x, y, w, h, title)
  checkArg(1, x, "number")
  checkArg(2, y, "number")
  checkArg(3, w, "number")
  checkArg(4, h, "number")
  checkArg(5, title, "string", "nil")
  title = title or "New Window"
  if #title > (w - 4) then title = title:sub(w - 7) .. "..." end
  local window = lib.window.create(x, y, w, h)
  local titlebar = lib.UIPage:new {
    x = 1, y = 1, w = window.w, h = 1,
    fg = colorscheme.textcol_titlebar, bg = colorscheme.bg_titlebar,
    text = title, surface = window.buffer
  }
  local close = lib.Clickable:new {
    x = window.w - 3, y = 1, w = 3, h = 1, text = " \215 ",
    fg = colorscheme.textcol_close, bg = colorscheme.bg_close,
    callback = function()
      window.delete = true
    end
  }
  local body = lib.UIPage:new {
    x = 1, y = 2, w = window.w, h = window.h - 1,
    fg = colorscheme.textcol_default, bg = colorscheme.bg_default,
    surface = window.buffer
  }
  titlebar:addChild(close)
  window:addPage("titlebar", titlebar)
  window:addPage("base", body)
  window:setPage("base")
  return window, body
end

-- an event loop that should suffice for most apps
function lib.util.genericWindowLoop(win, handlers)
  checkArg(1, win, "table")
  checkArg(2, handlers, "table", "nil")
  local focusedElement
  while not win.delete do
    if handlers and handlers.generic then pcall(handlers.generic) end
    win:draw()
    local signal = win:receiveSignal()
    if sigtypes.keyboard[signal[1]] then
      if focusedElement and focusedElement.handleKey then
        focusedElement:handleKey(signal[1], signal[2])
      end
    elseif sigtypes.mouse[signal[1]] then
      if signal[1] == "mouse_drag" then
        win.dragging = true
      elseif signal[1] == "mouse_scroll" then
        local element = win:find(signal[3], signal[4], true)
        if element and element.scrollY and element.child then
          element.scrollY = math.max(0, math.min(element.child.h - element.h,
            element.scrollY + signal[2]))
        end
      elseif signal[1] == "mouse_click" then
        local element = win:find(signal[3], signal[4])
        focusedElement = element or focusedElement
        if element then
          element:callback()
        end
      end
    end
    if handlers and handlers[signal[1]] then
      pcall(handlers[signal[1]], table.unpack(signal, 1, signal.n))
    end
  end
end

function lib.util.prompt(text, opts)
  checkArg(1, text, "string")
  checkArg(2, opts, "table")
  local lines = textutils.wordwrap(text, 24)
  local window, base = lib.util.basicWindow(5, 4,
    24, #lines + 3,
    opts.title or "Prompt")
  local result = ""
  base:addChild(lib.Label:new {
    x = 2, y = 1, w = window.w - 2, h = window.h - 1,
    text = text, wrap = true
  })
  local x = window.w + 1
  for i=#opts, 1, -1 do
    x = x - #opts[i] - 1
    base:addChild(lib.Clickable:new {
      x = x, y = window.h - 1, w = #opts[i], h = 1,
      callback = function()
        result = opts[i]
        window.delete = true
      end, text = opts[i]
    })
  end
  while not window.delete do
    window:draw()
    local sig = window:receiveSignal()
    if sig[1] == "mouse_click" then
      local element = window:find(sig[3], sig[4])
      if element then
        element:callback(sig[2])
      end
    elseif sig[1] == "mouse_drag" then
      window.dragging = true
    elseif sig[1] == "mouse_up" then
      window.dragging = false
    end
  end
  return result
end

return lib
