-- the .OS file manager --

local dotos = require("dotos")
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
  x = 1, y = 4, w = base.w, h = base.h - 4, child = fsurf
}

base:addChild(scrollable)
base:addChild(dotui.Label:new {
  x = 1, y = 3, w = base.w, h = 1,
  text = string.format("%s | %s | %s | %s",
    textutils.padRight("Name", 12),
    textutils.padRight("Size", 6),
    textutils.padRight("Type", 4),
    "Last Modified")
})

local topbar = dotui.UIPage:new {
  x = 1, y = 1, w = base.w, h = 2, bg = colors.clickable_bg_default,
}

local fents = {}
local buildFileUI
local topbuttons = {
  {"File", {
      {"Open", function(self)
        self.selected = 0
        if fsurf.selected == 0 then
          dotui.util.prompt("Select a file first.", {"OK"})
          return
        end
        dotui.util.prompt("This functionality is not implemented.", {"OK"})
      end},
      {"Execute", function(self)
        self.selected = 0
        if fsurf.selected == 0 then
          dotui.util.prompt("Select a file first.", {"OK"})
          return
        end
        dotos.spawn(function()
          dofile(fents[fsurf.selected].absolute)
        end, fents[fsurf.selected].file)
      end},
      {"Quit", function(self)
        dotos.exit()
      end},
    }
  },
  {"Edit", {
      {"Delete", function(self)
        self.selected = 0
        if fsurf.selected == 0 then
          dotui.util.prompt("Select a file first.", {"OK"})
          return
        end
        local res = dotui.util.prompt("Really delete?", {"Yes", "No"})
        if res == "Yes" then
          fs.delete(fents[fsurf.selected].file)
          buildFileUI(fents[fsurf.selected].absolute)
        end
      end},
    }
  },
  {"Help", {
      {"About", function(self)
        dotui.util.prompt("The File Mangler was written by Ocawesome101.  It is a simple file manager for DoT OS.",
          {"Close"})
      end},
    }
  }
}

base:addChild(topbar)
do
  local x = 1
  for i, menu in ipairs(topbuttons) do
    local items, callbacks = {}, {}
    local w = 0
    for n, item in ipairs(menu[2]) do
      items[n] = item[1]
      if #items[n] > w then w = #items[n] end
      callbacks[n] = item[2]
    end
    w = w + 1
    base:addChild(dotui.Dropdown:new {
      x = x, y = 2, text = menu[1], w = w, h = #items + 1,
      items = items, callbacks = callbacks
    })
    x = x + w + 2
  end
end

local ftext = dotui.Label:new {
  x = 3, y = 1, w = base.w - 4, h = 1, text = "/"
}

topbar:addChild(ftext)

buildFileUI = function(dir)
  ftext.text = dir
  local files = fs.list(dir)
  table.sort(files)
  fsurf.children = {}
  fsurf.h = #files
  fsurf.selected = 0
  fents = {}
  scrollable.scrollX = 0
  scrollable.scrollY = 0
  for i, file in ipairs(files) do
    local absolute = fs.combine(dir, file)
    local attr = fs.attributes(absolute)
    if #file > 12 then file = file:sub(1, 9) .. "..." end
    file = textutils.padRight(file, 12)
    local size = sizes.format1024(attr.size)
    local text = string.format("%s | %s | %s | %s",
      file, textutils.padRight(size, 6),
      attr.isDir and "dir " or "file",
      os.date("%Y/%m/%d %H:%M", math.floor((attr.modified or 0) / 1000)))
    fents[#fents+1] = {
      absolute = absolute, file = file,
    }
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

topbar:addChild(dotui.Clickable:new {
  x = 1, y = 1, w = 2, h = 1, text = "\24", callback = function()
    if ftext.text ~= "/" then
      local parent = fs.getDir(ftext.text)
      if fs.exists(parent) then
        buildFileUI(parent)
      end
    end
  end
})

buildFileUI("/")

dotui.util.genericWindowLoop(window)

dotos.exit()
