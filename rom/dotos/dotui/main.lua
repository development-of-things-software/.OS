-- main .UI file --
-- this is the low-level-ish window manager

dotos.log("[.ui] The DoT UI is now starting")

local term = require("term")
local buf = require("dotui.buffer")

-- shared surfaces
local surf = require("dotui.surf")
local surfaces = surf.getSurfaceTable()

local master_surf = buf.new(term.getSize())

local function findOverlap(x, y)
  for i=1, #surfaces, 1 do
    if x >= surfaces[i].x and x <= surfaces[i].x + surfaces[i].w - 1 and
        y >= surfaces[i].y and y <= surfaces[i].y + surfaces[i].h - 1 then
      return i, surfaces[i]
    end
  end
end

-- signals to send only to the focused surface
local focused_only = {
  mouse_click = true,
  mouse_drag = true,
  mouse_scroll = true,
  mouse_up = true,
  key = true,
  key_up = true,
  char = true
}

while true do
  for i=#surfaces, 1, -1 do
    surfaces[i]:redraw(master_surf)
  end
  master_surf:redraw(1, 1)
  local sig = table.pack(coroutine.yield())
  if sig.n > 0 then
    local target = surfaces[1]
    if sig[1] == "term_resize" then
      master_surf:resize(term.getSize())
    elseif sig[1] == "mouse_click" then
      local i, surface = findOverlap(sig[3], sig[4])
      if i then
        if i ~= 1 then
          table.remove(surfaces, i)
          table.insert(surfaces, 1, surface)
          target = surface
        end
      else
        target = desktop
      end
    end
    if sig[1] == "mouse_click" or sig[1] == "mouse_up" or sig[1] == "mouse_drag"
        or sig[1] == "mouse_scroll" then
      sig[3] = sig[3] - (target.x or 1) + 1
      sig[4] = sig[4] - (target.y or 1) + 1
    end
    if focused_only[sig[1]] then
      target:sendSignal(sig)
    else
      for i=1, #surfaces, 1 do
        surfaces[i]:sendSignal(sig)
      end
    end
  end
end
