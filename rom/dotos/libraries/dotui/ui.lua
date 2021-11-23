-- the .OS GUI toolkit --

local split = require("text").split
local surface = require("dotui.surface")

local ui = {}

local _page = {}

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
end

function ui.page(pages)
  return setmetatable({
    pages = pages or {},
    surface = surface.new(1,1,1,1)
    children = {}
  }, {__index = _page})
end

local PAGE_PATTERN = "([^ ]+) %b{}"

local function eval(line)
  local words = split(line, " ")
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
      page[method](page, args)
    end
    pages[pagename] = page
  end
end

return ui
