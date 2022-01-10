-- The DoT OS Window Manager --

local ipc = require("ipc")
local term = require("term")
local state = require("state")
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
  function rootwindow.addWindow(element)
    local id
    repeat
      id = math.random(100000, 999999)
    until not windows[id]
    windows[id] = element
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

while true do
  -- draw all the windows
  for k, v in pairs(windows) do
    v:draw(1, 1)
  end
  -- blit them back-to-front to the root window
  for i=#stack, 1, -1 do
    local win = windows[stack[i]]
    win.surface:blit(rootwindow.surface, 1, 1)
  end
  -- draw the root window to the screen
  rootwindow.surface:draw(1, 1)

  local sig = table.pack(coroutine.yield())
  if sig.n == 0 then
    local ipcreq = table.pack(ipc.raw.receive())
    -- this is the method an application should use to request the
    -- root window object
    if ipcreq[2] == "connect" then
    end
  elseif sig[1] == "term_resize" then
    rootwindow.surface:resize(term.getSize())
  elseif sigtypes.mouse[sig[1]] then
    local win = rootwindow
    local button, x, y = table.unpack(sig, 2, sig.n)
    for i=1, #stack, 1 do
      local w = windows[stack[i]]
      if x >= w.x and x <= w.x + w.w - 1 and
         y >= w.y and y <= w.y + w.h - 1 then
        win = w
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
      windows[stack[1]]:handle(sig[1], sig[2], sig[3])
    end
  end
end
