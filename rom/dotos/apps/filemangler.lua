-- the .OS file manager --

local dotui = require("dotui")
local colors = require("dotui.colors")
local fs = require("fs")
local textutils = require("textutils")
local sizes = require("sizes")

local window, base = dotui.util.basicWindow(1, 2, 50, 16, "File Mangler")

-- this is dynamically resized for however many files there may be
local fsurf = dotui.UIPage:new {
  x = 1, y = 1, w = base.w, h = 1
}

local scrollable = dotui.Scrollable:new {
  x = 2, y = 4, w = base.w, h = base.h - 4, child = fsurf
}

base:addChild(scrollable)
base:addChild(dotui.Label:new {
  x = 1, y = 3, w = base.w, h = 1,
  text = string.format("%s | %s | %s | %s",
    textutils.padRight("Name", 12),
    textutils.padRight("Size", 6),
    textutils.padRight("Type", 9),
    "Last Modified")
})

local topbar = dotui.UIPage:new {
  x = 1, y = 1, w = base.w, h = 2, bg = colors.clickable_bg_default,
}

local ftext = dotui.Label:new {
  x = 3, y = 1, w = base.w - 4, h = 1, text = "/"
}

topbar:addChild(ftext)
base:addChild(topbar)

local buildFileUI
buildFileUI = function(dir)
  ftext.text = dir
  local files = fs.list(dir)
  table.sort(files)
  fsurf.children = {}
  fsurf.h = #files
  fsurf.selected = 0
  for i, file in ipairs(files) do
    local absolute = fs.combine(dir, file)
    local attr = fs.attributes(absolute)
    if #file > 12 then file = file:sub(1, 9) .. "..." end
    file = textutils.padRight(file, 12)
    local size = sizes.format1024(attr.size)
    local text = string.format("%s | %s | %s | %s",
      file, textutils.padRight(size, 6),
      attr.isDir and "directory" or "file     ",
      os.date("%Y/%m/%d %H:%M:%S", math.floor(attr.modified / 1000)))
    fsurf:addChild(dotui.Clickable:new {
      x = 1, y = i, w = base.w, h = 1, callback = function(self)
        if fsurf.selected == i and os.epoch("utc") - self.click <= 500 then
          if attr.isDir then
            buildFileUI(absolute)
          else
            dotui.util.prompt("Please choose an action from the menu bar.",
              {"OK"})
          end
        else
          self.click = os.epoch("utc")
          fsurf.selected = i
          for i=1, #fsurf.children, 1 do
            fsurf.children[i].bcolor = colors.bg_default
          end
          self.bcolor = colors.accent_color
        end
      end, text = text, bg = colors.bg_default
    })
  end
  fsurf.surface:resize(fsurf.w, fsurf.h)
end

buildFileUI("/")

dotui.util.genericWindowLoop(window)

dotos.exit()
