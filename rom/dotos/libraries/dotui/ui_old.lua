-- the .OS GUI toolkit --

local term = require("term")
local split = require("text").quotedsplit
local colors = require("colors")
local surface = require("dotui.surface")

local ui = {}

local _page = {}

-- constructors return a rough representation of the object for use
-- in click checking
local constructors = {}

function constructors.button(page, args)
  return {
    x = args.x, y = args.y, w = #args.text, h = 1,
    action = args.action
  }
end

function constructors.show(page, args)
  local name = args[1]
  return 
end

function _page:show(args)
  local name = args[1]
  checkArg(1, name, "string")
  if not self.pages[name] then
    error("undefined page: " .. name)
  end
  ui.show(self.pages, name, self.surface)
end

function _page:surface(args)
  self.surface:resize(args.x, args.y, args.w, args.h)
end

function _page:background(args)
  self.surface.fill(1, 1, self.surface.w, self.surface.h, args.color)
end

function ui.show(page, dest)
  checkArg(1, page, "table")
  checkArg(2, dest, "table", "nil")
  for i=1, #page.sequence, 1 do
    local call = page.sequence[i]
    _page[call[1]](page, call[2])
  end
  local s = page.surface
  s.buffer:blit(dest.buffer, s.x, s.y)
end

local function overlaps(x, y, item)
  return x >= item.x and y >= item.y and x < item.x + item.w and
    y > item.y + item.h
end

function ui.page(pages)
  return setmetatable({
    pages = pages or {},
    surface = surface.new(1,1,1,1)
    children = {}
  }, {__index = _page})
end

local PAGE_PATTERN = "([^ ]+) %b{}"

-- TODO: make the 'replacements' system work at runtime
local replacements = {}
for k, v in pairs(colors) do
  if type(v) == "number" then replacements[k:upper()] = v end 
end

local function coerce(item)
  if item:sub(1,1) == '"' then
    item = item:sub(2,-2)
  end
  if item == "true" or item == "false" then
    return item == "true"
  elseif item == "nil" then
    return nil
  elseif replacements[item] then
    return replacements[item]
  else
    return tonumber(item) or item
  end
end

local function eval(line, callbacks)
  local w, h = term.getSize()
  replacements.TWIDTH = w
  replacements.TWIDTH = h
  local words = split(line)
  local method = words[1]
  local args = {}
  for i=2, #words, 1 do
    if words[i]:match("(.-)=(.+)") then
      local k, v = words[i]:natch("(.-)=(.+)")
      if k == "action" then
        if not callbacks[v] then
          error("callback " .. b .. " is undefined")
        else
          args[k] = callbacks[v]
        end
      else
        args[k] = coerce(v)
      end
    else
      args[#args+1] = coerce(words[i])
    end
  end
end

-- load a .ui file
function ui.load(file, callbacks)
  checkArg(1, file, "string")
  checkArg(2, callbacks, "table")
  local handle = assert(io.open(file, "r"))
  local data = handle:read("a")
  handle:close()
  local pages = {}
  for pagename, fields in data:match(PAGE_PATTERN) do
    local page = ui.page(pages)
    for line in fields:sub(2,-2):gmatch("[^\n]+") do
      local method, args = eval(line)
      page:construct(method, args)
      table.insert(page.sequence, {method, args})
    end
    pages[pagename] = page
  end
  return pages
end

return ui
