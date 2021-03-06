-- The DoT OS Window Manager --

local ipc = require("ipc")
local term = require("term")
local dotos = require("dotos")
local state = require("state")
local colors = require("colors")
local surface = require("surface")
local sigtypes = require("sigtypes")

local wms = state.create(".wm.state")

-- all windows currently registered
wms.windows = wms.windows or {}
local windows = wms.windows
-- the stack order of those windows
wms.stack = wms.stack or {}
local stack = wms.stack

if not wms.rootwindow then
  local rootwindow = {
    surface = surface.new(term.getSize())
  }

  -- expects a .TK element
  function rootwindow.addWindow(element, position)
    local id
    repeat
      id = math.random(100000, 999999)
    until not windows[id]
    if position == "centered" then
      local w, h = term.getSize()
      element.x = math.floor(w/2) - math.floor(element.w/2)
      element.y = math.floor(h/2) - math.floor(element.h/2)
    else
      element.x = element.x or 1
      element.y = element.y or 1
    end
    windows[id] = element
    element.pid = dotos.getpid()
    table.insert(stack, 1, id)
    return id
  end

  function rootwindow.removeWindow(id)
    checkArg(1, id, "number")
    if not windows[id] then
      return nil, "Window not present"
    end
    windows[id] = nil
    return true
  end
  
  wms.rootwindow = rootwindow
end

local rootwindow = wms.rootwindow

local dragxoffset, dragyoffset

dotos.logio = nil
while true do
  rootwindow.surface:fill(1, 1, rootwindow.surface.w, rootwindow.surface.h, " ",
    colors.blue, colors.blue)
  -- draw all the windows
  for k, v in pairs(windows) do
    if not dotos.running(v.pid) then
      windows[k] = nil
    else
      v:draw(1, 1)
    end
  end
  -- blit them back-to-front to the root window
  for i=#stack, 1, -1 do
    local win = windows[stack[i]]
    if not (win and dotos.running(win.pid)) then
      table.remove(stack, i)
    else
      win.surface:blit(rootwindow.surface, win.x, win.y)
    end
  end
  -- draw the root window to the screen
  rootwindow.surface:draw(1, 1)

  local sig = table.pack(coroutine.yield())
  if sig.n == 0 then
    local ipcreq = table.pack(ipc.raw.receive())
    -- this is the method an application should use to request the
    -- root window object
    if ipcreq[2] == "connect" then
      ipc.raw.respond(ipcreq[1], rootwindow)
    end
  elseif sig[1] == "term_resize" then
    rootwindow.surface:resize(term.getSize())
  elseif (sig[1] == "mouse_drag" or sig[1] == "mouse_up") and stack[1]
      and windows[stack[1]] and windows[stack[1]].dragging then
    local win = windows[stack[1]]
    if sig[1] == "mouse_up" then
      win.dragging = false
      dragxoffset, dragyoffset = nil, nil
    elseif sig[1] == "mouse_drag" then
      if not dragxoffset then
        dragxoffset, dragyoffset = sig[3] - win.x, sig[4] - win.y
      else
        win.x, win.y = sig[3] - dragxoffset, sig[4] - dragyoffset
      end
    end
  elseif sigtypes.mouse[sig[1]] then
    local win = rootwindow
    local button, x, y = table.unpack(sig, 2, sig.n)
    for i=1, #stack, 1 do
      local w = windows[stack[i]]
      w.x = w.x or 1
      w.y = w.y or 1
      if x >= w.x and x <= w.x + w.w - 1 and
         y >= w.y and y <= w.y + w.h - 1 then
        win = w
        local id = table.remove(stack, i)
        table.insert(stack, 1, id)
        sig[3] = sig[3] - w.x + 1
        sig[4] = sig[4] - w.y + 1
        break
      end
    end
    if win.handle then
      local element = win:handle(sig[1], sig[3], sig[4], sig[2])
      if element then
        element:process(sig[1], sig[3], sig[4], sig[2])
      end
    end
  elseif sigtypes.keyboard[sig[1]] then
    if stack[1] then
      local element = windows[stack[1]]:handle(sig[1], sig[2], sig[3])
      if element then
        element:process(sig[1], sig[2], sig[3])
      end
    end
  end
end
