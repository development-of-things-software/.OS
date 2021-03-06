-- .TK: the DoT OS UI toolkit v2 --

local fs = require("fs")
local keys = require("keys")
local surface = require("surface")
local settings = require("settings")
local sigtypes = require("sigtypes")
local resources = require("resources")
local textutils = require("textutils")

local colors = assert(resources.load("dottk/default"))

colors.button_color = colors.button_color or colors.base_color
colors.button_text = colors.button_text or colors.text_color
colors.titlebar_text = colors.titlebar_text or colors.text_color
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
-- for some signal types.  for others (e.g. keypresses) they
-- are actually the other signal arguments, so when handling
-- only keypresses it is probably reasonable to name them
-- something else.
function _element:handle(sig, x, y, b) end

-- :resize() - takes a width and a height, and resizes
-- the element accordingly.
function _element:resize() end

-- the following methods are optional
-- :focus() - called when the element is focused
function _element:focus() end
-- :unfocus() - called when the element is unfocused
function _element:unfocus() end
-- :process() - called by the window manager on the
-- element returned from :handle().  arguments are
-- the same as to :handle().
function _element:process(sig, x, y, b) end


local tk = {colors = colors}

-- generic element
tk.Element = _element:inherit()


--== Interface building blocks ==--

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
  self.windowid = self.root.addWindow(self, args.position)
end

function tk.Window:draw()
  -- draw self
  self.surface:fill(1, 1, self.w, self.h, " ", 1, colors.base_color)
  -- draw all elements
  for k, v in pairs(self.children) do
    v:draw(v.x, v.y)
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


function tk.Window:addChild(x, y, element)
  checkArg(1, element, "table")
  element.x = x
  element.y = y
  local id = #self.children + 1
  self.children[id] = element
  element.childid = id
  return self
end

function tk.Window:handle(sig, x, y, b)
  -- check children
  if tonumber(x) and tonumber(y) then
    for i, c in ipairs(self.children) do
      if x >= c.x and y >= c.y and x < c.x + c.w and y < c.y + c.h then
        local nel = c:handle(sig, x - c.x + 1, y - c.y + 1, b)
        if nel and self.focused ~= nel then
          if self.focused then self.focused:unfocus() end
          nel:focus()
        end
        self.focused = nel or self.focused
        if nel then return nel end
      end
    end
    if sig == "mouse_click" and self.focused then
      self.focused:unfocus()
    end
  elseif self.focused then
    return self.focused:handle(sig, x, y, b)
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
  self.child.w = self.child.w or 100 or args.w - 1
  self.child.h = self.child.h or 100 or args.h
  self.child.window = {w = self.child.w, h = self.child.h}
  self.child.window.surface = surface.new(self.child.w, self.child.h)

  self.childid = #args.window.children+1
  args.window.children[self.childid] = self
end

function tk.View:xscroll(n)
  checkArg(1, n, "number")
  self.xscrollv = math.max(0, math.min(self.child.w - self.w, self.xscrollv+n))
end

function tk.View:yscroll(n)
  checkArg(1, n, "number")
  self.yscrollv = math.max(0, math.min(self.child.h - self.h, self.yscrollv+n))
end

function tk.View:draw(x, y)
  self.buffer:fill(1, 1, self.w, self.h, " ", colors.base_color,
    colors.base_color)
  self.child.window.surface:fill(1, 1, self.child.window.surface.w,
    self.child.window.surface.h, " ", colors.base_color, colors.base_color)
  self.child:draw(1, 1)
  self.child.window.surface:blit(self.buffer, 1 - self.xscrollv,
    1 - self.yscrollv)
  -- now draw scrollbars
  local scroll_y = math.floor((self.h - 1) * (self.yscrollv /
    (self.child.window.surface.h - self.h)))
  local scroll_x = math.floor((self.w - 1) * (self.xscrollv /
    (self.child.window.surface.w - self.w)))
  if self.h < self.child.h then
    self.buffer:fill(x + self.w, y, 1, self.h, " ", colors.base_color_light,
      colors.base_color_light)
    self.buffer:set(x + self.w, y + scroll_y, "\127", colors.base_color)
  end

  if self.w < self.child.w then
    self.buffer:fill(x, y + self.h, self.w, 1, " ", colors.base_color_light,
      colors.base_color_light)
    self.buffer:set(x + scroll_x, y + self.h, "\127", colors.base_color)
  end
  
  self.buffer:blit(self.surface, x, y)
end

function tk.View:handle(sig, x, y, b)
  if x and y then x, y = x - self.xscrollv, y - self.yscrollv end
  return self.child:handle(sig, x, y, b)
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
  checkArg("rows", args.rows, "number", "nil")
  checkArg("cols", args.cols or args.columns, "number", "nil")
  local window = args.window
  self.window = window
  local surface = window.surface
  self.x = 1
  self.y = 1
  self.w = args.w or window.w
  self.h = args.h or window.h
  self.rows = args.rows or 0
  self.columns = args.cols or args.columns or 0
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
  return self
end

function tk.Grid:draw(x, y)
  for r, row in pairs(self.children) do
    for c, col in pairs(row) do
      local cw, ch = col.w or math.huge, col.h or math.huge
      col:resize(self.cwidth, self.rheight)
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

function tk.Grid:handle(sig, x, y, b)
  if x and y then
    for r, row in pairs(self.children) do
      for c, col in pairs(row) do
        local check = {
          x = self.cwidth * (c-1) + 1,
          y = self.rheight * (r-1) + 1,
          w = self.cwidth,
          h = self.rheight
        }
        if x >= check.x and y >= check.y and
           x <= check.x + check.w - 1 and y <= check.y + check.h - 1 then
          local n = col:handle(sig, x - check.x + 1,
            y - check.y + 1, b)
          if n then return n end
        end
      end
    end
  end
end

-- Text: display some text
-- this widget will automatically word-wrap the text it is given.  it
-- will support text selection and copying in the future, once there
-- is a system clipboard.
tk.Text = tk.Element:inherit()
function tk.Text:init(args)
  checkArg(1, args, "table")
  checkArg("window", args.window, "table")
  checkArg("text", args.text, "string", "function")
  checkArg("position", args.position, "string", "nil")
  checkArg("width", args.width, "number", "nil")
  self.window = args.window
  self.text = args.text
  self.position = args.position
  self.width = args.width or 1
  local text = type(self.text) == "function" and self.text(self) or self.text
  self.w = self.w or #text
  local nw = math.ceil(self.w * self.width)
  self.h = self.h or #(self.wrap and textutils.wordwrap(text, nw)
    or textutils.lines(text))
end

function tk.Text:resize(w, h)
  checkArg(1, w, "number")
  checkArg(2, h, "number")
  self.w = w
  self.h = h
end

-- TODO: properly handle ctrl-C (copying) and text selection
function tk.Text:handle(sig, x, y, b)
  return nil
end

function tk.Text:draw(x, y)
  local text = type(self.text) == "function" and self.text(self) or self.text
  self.w = self.w or #text
  local nw = math.ceil(self.w * self.width)
  self.h = self.h or #(self.wrap and textutils.wordwrap(text, nw)
    or textutils.lines(text))
  -- word-wrap
  if self.wrap then
    self.lines = textutils.wordwrap(text, nw)
  else
    self.lines = textutils.lines(text)
  end
  for i, line in ipairs(self.lines) do
    if i > self.h then break end
    local xp = 0
    if self.position == "center" then
      if nw > #line then
        xp = math.floor(nw / 2 + 0.5) - math.floor(#line / 2 + 0.5)
      end
    elseif self.position == "right" then
      xp = nw - #line
    end
    xp = xp + math.ceil(self.w * (1 - self.width))
    line = (" "):rep(xp) .. line
    self.window.surface:set(x, y+i-1, textutils.padRight(line, nw),
      self.textcol or colors.text_color, self.bgcol or colors.base_color)
  end
end

-- Button: a clickable element that performs an action.
-- this specific implementation of Button may be disabled,
-- and will dynamically draw itself to fit the whole available
-- space.
tk.Button = tk.Text:inherit()
function tk.Button:init(args)
  tk.Text.init(self, args)
  checkArg("callback", args.callback, "function", "nil")
  self.w = #args.text
  self.h = 1
  self.callback = args.callback or function() end
  self.disabled = false
  self:unfocus()
end

function tk.Button:handle(sig, x, y, b)
  if sigtypes.click[sig] then
    return self
  end
end

function tk.Button:focus()
  self.bgcol = colors.accent_color
  self.textcol = colors.accent_comp
end

function tk.Button:unfocus()
  self.bgcol = colors.button_color
  self.textcol = colors.button_text
end

function tk.Button:process()
  return self:callback()
end

-- Checkbox: checkbox element
-- derived from the Button element.
tk.Checkbox = tk.Button:inherit()

local function checkbox_callback(c)
  c.selected = not c.selected
  if c.additional_callback then
    c:additional_callback()
  end
end

function tk.Checkbox:init(args)
  tk.Button.init(self, args)
  self.callback = checkbox_callback
  self.additional_callback = args.callback
  self.text = "   " .. self.text
end

function tk.Checkbox:draw(x, y)
  tk.Text.draw(self, x, y)
  if self.selected then
    self.window.surface:set(x+1, y, "x", colors.accent_comp,
      colors.accent_color)
  else
    self.window.surface:set(x+1, y, " ", colors.accent_color,
      colors.accent_color)
  end
end

-- tk.Button defines these, but we don't want them
function tk.Checkbox:focus() end
function tk.Checkbox:unfocus() end

-- MenuButton: show a menu of elements
-- this cannot display submenus
tk.MenuButton = tk.Button:inherit()
function tk.MenuButton:init(args)
  tk.Button.init(self, args)
  checkArg("items", args.items, "table")
  self.items = args.items
  self.menu_w = 0
  for i=1, #self.items, 1 do
    self.menu_w = math.max(#self.items[i], self.menu_w)
  end
end

function tk.MenuButton:handle(sig)
  if sigtypes.click[sig] then
    return self
  end
end

function tk.MenuButton:process()
  if self.menuwindow then
    self:unfocus()
  else
    self.menuwindow = tk.Window:new {
      root = self.window.root,
      w = self.menu_w, h = #self.items
    }
    function self.menuwindow:unfocus()
      self.root.removeWindow(self.windowid)
    end
    for i=1, #self.items, 1 do
      self.menuwindow:addChild(1, i, tk.Button:new {
        text = items[i].text,
        callback = items[i].callback
      })
    end
  end
end

function tk.MenuButton:unfocus()
  if self.menuwindow then
    self.window.root.removeWindow(self.menuwindow.windowid)
    self.menuwindow = nil
  end
end

-- MenuBar: a bar of MenuButtons
-- takes a structure like this:
--  {
--    {
--      "File", {
--        { text = "Save", callback = function() ... end },
--        { text = "Quit", callback = function() ... end }
--      }
--    },
--    {
--      "Edit", {
--        { text = "Preferences", callback = function() ... end }
--      }
--    }
--    -- and this structure is merged with the 'args' table:
--    window = <tk.Window>,
--  }
tk.MenuBar = tk.Element:inherit()
function tk.MenuBar:init(args)
  checkArg(1, args, "table")
  checkArg("window", args.window, "table")
  self.window = args.window
  self.items = {}
  for i=1, #args, 1 do
    local new = tk.MenuButton:new {
      window = self.window,
      text = key,
      items = args[i],
    }
    new.w = #key
    new.h = 1
    self.items[#self.items+1] = new
  end
end

function tk.MenuBar:draw(x, y)
  self.window.surface:fill(x, y, self.window.surface.w, 1, " ",
    colors.base_color, colors.button_text)
  local xo = 0
  for i, item in ipairs(self.items) do
    self.window.surface.set(x + xo, y, item.text)
    xo = xo + #item.text + 1
  end
end

function tk.MenuBar:handle(sig, x, y)
  if sigtypes.click[sig] then
    local xo = 0
    for i, item in ipairs(self.items) do
      local nxo = xo + #item.text + 1
      if x >= xo and x <= nxo then
        return item
      end
    end
  end
end

-- InputBox: reads a single line of input
tk.InputBox = tk.Element:inherit()
function tk.InputBox:init(args)
  checkArg(1, args, "table")
  checkArg("window", args.window, "table")
  checkArg("mask", args.mask, "string", "nil")
  checkArg("text", args.text, "string", "nil")
  checkArg("width", args.width, "number", "nil")
  checkArg("onchar", args.onchar, "function", "nil")
  checkArg("position", args.position, "string", "nil")
  self.window = args.window
  self.position = args.position
  self.width = args.width or 1
  self.buffer = args.text or ""
  self.onchar = args.onchar or function() end
  self.mask = args.mask
end

function tk.InputBox:resize(w, h)
  self.w = w
  self.h = h
end

function tk.InputBox:draw(x, y)
  local nw = math.ceil(self.w * self.width)
  local xp = 0
  if self.position == "center" then
    xp = math.floor(self.w / 2 + 0.5) - math.floor(nw / 2 + 0.5)
  elseif self.position == "right" then
    xp = self.w - nw
  end
  local text = textutils.padRight(
    (self.mask and self.buffer:gsub(".", self.mask:sub(1,1))
     or self.buffer) .. (self.focused and "|" or ""), nw):sub(-nw)
  self.window.surface:set(x + xp, y, text, colors.text_color,
    colors.base_color_light)
end

function tk.InputBox:handle(sig)
  if sig == "key" or sig == "char" or sig == "mouse_click" then
    return self
  end
end

function tk.InputBox:process(sig, coc)
  if sig == "char" then
    self.buffer = self.buffer .. coc
    self:onchar()
  elseif sig == "key" then
    if coc == keys.backspace and #self.buffer > 0 then
      self.buffer = self.buffer:sub(1, -2)
    end
    self:onchar()
  end
end

function tk.InputBox:focus()
  self.focused = true
end

function tk.InputBox:unfocus()
  self.focused = false
end

--== More complex utility elements ==--

-- TitleBar: generic window title bar
tk.TitleBar = tk.Element:inherit()
function tk.TitleBar:init(args)
  checkArg(1, args, "table")
  checkArg("window", args.window, "table")
  checkArg("text", args.text, "string", "nil")
  self.window = args.window
  self.text = args.text or ""
end

function tk.TitleBar:draw()
  self.w = self.window.w
  self.h = 1
  self.window.surface:fill(1, 1, self.window.w, 1, " ", colors.titlebar_text,
    colors.titlebar)
  local tx = math.floor(self.w / 2 + 0.5) - math.floor(#self.text/2 + 0.5)
  self.window.surface:set(tx, 1, self.text)
  self.window.surface:set(self.window.w - 3, 1, " x ", colors.accent_comp,
    colors.accent_color)
end

function tk.TitleBar:handle(sig, x)
  if sigtypes.click[sig] then
    return self
  end
end

function tk.TitleBar:process(sig, x)
  if x > self.window.w - 4 then
    self.window.root.removeWindow(self.window.windowid)
    self.window.closed = true
  else
    self.window.dragging = true
  end
end

tk.Dialog = tk.Window:inherit()
function tk.Dialog:init(args)
  checkArg(1, args, "table")
  args.w = args.w or 15
  args.h = args.h or 8
  args.position = "centered"
  tk.Window.init(self, args)
  checkArg("text", args.text, "string")
  self:addChild(1, 1, tk.TitleBar:new { window = self })
  local text = tk.Text:new {
    window = self,
    text = args.text,
  }
  text.wrap = true
  text.w = args.w
  self:addChild(1, 2, tk.View:new {
    window = self, w = args.w, h = args.h - 2,
    child = text
  })
  self:addChild(1, self.h, tk.Grid:new({
    window = self, rows = 1, columns = 3
  }):addChild(1, 3, tk.Button:new {
    window = self, text = "OK", callback = function(self)
      self.window.root.removeWindow(self.window.windowid)
      self.closed = true
    end
  }))
end

--== Miscellaneous ==--

function tk.useColorScheme(name)
  checkArg(1, name, "string")
  colors = assert(resources.load("dottk/"..name))
end

return tk
