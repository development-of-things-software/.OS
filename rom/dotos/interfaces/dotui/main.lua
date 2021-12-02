-- main .UI file --
-- this is the low-level-ish window manager

dotos.log("[.ui] The DoT UI is now starting")

local term = require("term")
local surf = require("surface")
local colors = require("colors")
local sigtypes = require("sigtypes")
local cfg = require("settings").load("/.dotos.cfg")

package.loaded["dotui.colors"] =
  dofile("/dotos/resources/dotui/colors/"..cfg.colorScheme..".lua")
local colorscheme = require("dotui.colors")

-- shared windows
local win = require("dotui").window
local windows = win.getWindowTable()

local master_surf = surf.new(term.getSize())

-- draw startup logo on the master surface for a more seamless transition
local w,h = master_surf.w, master_surf.h
master_surf:fill(1, 1, master_surf.w, master_surf.h, " ", colors.gray,
  colors.lightBlue)
master_surf:fill(math.floor(w/2) - 7, math.floor(h/2) - 1, 19, 4, " ",
  colors.gray, colors.gray)
master_surf:fill(math.floor(w/2) - 8, math.floor(h/2) - 2, 19, 4, " ",
  colors.gray, colors.lightGray)
master_surf:set(math.floor(w/2) - 7, math.floor(h/2) - 1, os.version())
master_surf:set(math.floor(w/2) - 7, math.floor(h/2), "  by DoT Software")
master_surf:draw(1, 1)

local function findOverlap(x, y)
  for i=1, #windows, 1 do
    if x >= windows[i].x and x < windows[i].x + windows[i].w and
        y >= windows[i].y and y < windows[i].y + windows[i].h then
      return i, windows[i]
    end
  end
end

-- load the main desktop
local deskpid = 0
local function spawn_desktop()
  deskpid = dotos.spawn(assert(loadfile("/dotos/interfaces/dotui/desktop.lua")),
    "desktop")
end
dotos.show_logs = true

-- signals to send only to the focused window
local focused_only = {
  mouse_click = true,
  mouse_drag = true,
  mouse_scroll = true,
  mouse_up = true,
  key = true,
  key_up = true,
  char = true
}

local offsetX, offsetY = 0, 0
while true do
  if not dotos.running(deskpid) then
    spawn_desktop()
  end
  -- shove windows into the background that should be in the background
  for i=1, #windows, 1 do
    if windows[i].keepInBackground then
      table.insert(windows, #windows, table.remove(windows, i))
    end
  end
  -- shove windows into the foreground that should be in the foreground
  for i=#windows, 1, -1 do
    if windows[i].keepOnTop then
      table.insert(windows, 1, table.remove(windows, i))
    end
  end
  -- draw windows
  for i=#windows, 1, -1 do
    if windows[i].delete or not dotos.running(windows[i].pid or 0) then
      table.remove(windows, i)
    else
      if colorscheme.drop_shadow and not windows[i].noDropShadow then
        master_surf:fill(windows[i].x + 1, windows[i].y + 1, windows[i].w,
          windows[i].h, " ", 1, colorscheme.drop_shadow)
      end
      windows[i].buffer:blit(master_surf, windows[i].x, windows[i].y)
    end
  end
  master_surf:draw(1, 1)
  local sig = table.pack(coroutine.yield())
  if sig.n > 0 then
    local target = windows[1]
    if sig[1] == "term_resize" then
      master_surf:resize(term.getSize())
      windows[#windows].buffer:resize(term.getSize())
    elseif sigtypes.mouse[sig[1]] then
      if windows[1].dragging then
        target = windows[1]
      else
        local i, window = findOverlap(sig[3], sig[4])
        target = window
        if i ~= 1 and not window.keepInBackground then
          local win = table.remove(windows, i)
          windows[1]:sendSignal({"unfocus"})
          table.insert(windows, 1, win)
          windows[1]:sendSignal({"focus"})
        end
      end
    end
    if sig[1] == "mouse_drag" then
      if target.dragging then
        target.x, target.y = sig[3] - offsetX, sig[4] - offsetY
      else
        offsetX = sig[3] - target.x
        offsetY = sig[4] - target.y
      end
    elseif sig[1] == "mouse_up" then
      for i=1, #windows, 1 do windows[i].dragging = false end
      target.dragging = false
    end
    if not target.dragging then
      if sig[1] == "mouse_click" or sig[1] == "mouse_up" or
          sig[1] == "mouse_drag" or sig[1] == "mouse_scroll" then
        sig[3] = sig[3] - (target.x or 1) + 1
        sig[4] = sig[4] - (target.y or 1) + 1
      end
      if focused_only[sig[1]] then
        target:sendSignal(sig)
      else
        for i=1, #windows, 1 do
          windows[i]:sendSignal(sig)
        end
      end
    end
  end
end
