-- self extracting bootable mtar loader --
-- this is similar to the one used in Cynosure
-- except that it wraps the `fs' api rather than
-- presenting a custom fs tree for the OS to
-- do with that tree what it will.
-- this will only work with an MTAR v1 archive.
-- works by seeking to the first capital "z" in
-- itself, and loading the MTAR data from there.
--
-- must be run from CraftOS.

if not (os.version and os.version():match("CraftOS")) then
  error("This program requires CraftOS", 0)
end

local tree = {__is_a_directory=true}

local handle = assert(fs.open(shell.getRunningProgram(), "rb"))

print([[
This is the DoT OS self-extracting MTAR image.  It is intended for demo purposes only.  If you wish to use DoT OS as a standlone CraftOS replacement, use the provided datapack or install it to your root filesystem with the included installer utility.

Please report bugs with this program at https://github.com/development-of-things-software/.os.

Press RETURN to continue.]])

io.read()

write("Locating system data....")
local x, y = term.getCursorPos()

local offset = 0
repeat
  local c = handle.read(1)
  offset = offset + 1
  term.setCursorPos(x, y)
  term.write(tostring(offset))
until c == "\90" -- this is uppercase z, but putting one of those anywhere else
-- in the file would break this.  it's not a great solution, but it does work.
-- skip the newline immediately following that `z'
write("\n")
assert(handle.read(1) == "\n", "corrupt MTAR data")

local function split_path(path)
  local s = {}
  for _s in path:gmatch("[^\\/]+") do
    if _s == ".." then
      s[#s] = nil
    elseif s ~= "." then
      s[#s+1] = _s
    end
  end
  return s
end

local function add_to_tree(name, offset, len)
  print(name, offset)
  local cur = tree
  local segments = split_path(name)
  if #segments == 0 then return end
  for i=1, #segments - 1, 1 do
    local seg = segments[i]
    cur[seg] = cur[seg] or {__is_a_directory = true}
    cur = cur[seg]
  end
  cur[segments[#segments]] = {offset = offset, length = len}
end

local function read(n, offset)
  if offset then handle.seek("set", offset) end
  return handle.read(n)
end

-- avoid using string.unpack because that's not present in CC 1.89.2
local function bunpack(bytes)
  if not bytes then return nil end
  local result = 0
  for c in bytes--[[:reverse()]]:gmatch(".") do
    result = bit32.lshift(result, 8) + c:byte()
  end
  return result
end

local function read_header()
  handle.read(3) -- skip the MTAR v1 file header
  local namelen = bunpack(handle.read(2))
  local name = handle.read(namelen)
  local flen = bunpack(handle.read(8))
  if not flen then return end
  local foffset = handle.seek()
  handle.seek("cur", flen)
  add_to_tree(name, foffset, flen)
  return true
end

repeat until not read_header()

-- wrap the fs api so that the mtar file is the "root filesystem"
-- TODO: make there still be a way to access the real rootfs - 
--       perhaps put it at /fs or something?
-- TODO: make this emulate more of the `fs' API - currently it
--       only wraps what .OS needs

local function find_node(path)
  local segments = split_path(path)
  local node = tree
  for i=1, #segments, 1 do
    node = node[segments[i]]
    if not node then
      return nil, path .. ": File node does not exist"
    end
  end
  return node
end

local mtarfs = {}
function mtarfs.exists(path)
  return not not find_node(path)
end

function mtarfs.list(path)
  local items = {}
  local node, err = find_node(path)
  if not node then return nil, err end
  for k, v in pairs(node) do
    if k ~= "__is_a_directory" then
      items[#items+1] = k
    end
  end
  return items
end

function mtarfs.getSize(path)
  local node, err = find_node(path)
  if not node then return nil, err end
  return node.length or 0
end

function mtarfs.isDir(path)
  local node, err = find_node(path)
  if not node then return nil, err end
  return not not node.__is_a_directory
end

local readonly = "The filesystem is read-only"

function mtarfs.move()
  error(readonly, 0)
end

function mtarfs.copy()
  error(readonly, 0)
end

function mtarfs.delete()
  error(readonly, 0)
end

function mtarfs.open(file, mode)
  if mode:match("[wa]") then
    return nil, readonly
  end
  if not mode:match("r") then
    error("Invalid mode", 0)
  end
  local node, err = find_node(file)
  if not node then return nil, err end
  if node.__is_a_directory then return nil, "Is a directory" end
  local handle = {}
  local offset = 0
  local data = read(node.length, node.offset)
  function handle.read(num)
    assert(num > 0, "cannot read <=0 bytes")
    if offset == #data then return nil end
    local chunk = data:sub(offset, offset + num - 1)
    offset = offset + num
    return chunk
  end
  function handle.readAll()
    if offset == #data then return nil end
    local chunk = data:sub(offset)
    offset = #data
    return chunk
  end
  function handle.readLine(keepnl)
    if offset == #data then return nil end
    local nxnl = data:find("\n", offset) or #data
    local chunk = data:sub(offset, nxnl)
    offset = nxnl
    if chunk:sub(-1) == "\n" and not keepnl then chunk = chunk:sub(1,-2) end
    return chunk
  end
  function handle.close()
  end
  return handle
end

function mtarfs.find()
  error("fs.find is not supported under MTAR-FS", 0)
end

function mtarfs.attributes(path)
  local node, err = find_node(path)
  if not node then return nil, err end
  return {
    size = node.length or 0,
    isDir = not not node.__is_a_directory,
    isReadOnly = true,
    created = 0,
    modified = 0,
  }
end

function mtarfs.isReadOnly()
  return true
end

print("Starting UnBIOS...")
local handle = assert(mtarfs.open("/unbios.lua", "r"))
local data = handle.readAll()
handle.close()
for k, v in pairs(mtarfs) do
  _G.fs[k] = v
end
assert(load(data, "=unbios", "t", _G))()

--[=======[Z
?? bios.lua      &-- DOT-OS BIOS --

local term = term
term.clear()
local y = 1
local w, h = term.getSize()
term.setCursorBlink(true)

local function tprintf(fmt, ...)
  local ftext = string.format(fmt, ...)
  term.setCursorPos(1, y)
  for text in ftext:gmatch("[^\n]+") do
    while #text > 0 do
      local ln = text:sub(1, w)
      term.write(ln)
      text = text:sub(#ln + 1)
      if y == h then
        term.scroll(1)
      else
        y = y + 1
      end
      term.setCursorPos(1, y)
    end
  end
end

tprintf(".BIOS version 0.1.0")
tprintf(" - by Development of Things Software\n \nProbing boot files...")

local loadstr = load
if _VERSION == "Lua 5.1" then
  loadstr = loadstring
end

local function err(fmt, ...)
  term.setTextColor(0x4000)
  tprintf(fmt, ...)
  while true do coroutine.yield() end
end

local function boot(file)
  local handle, erro = fs.open(file, "r")
  if not file then
    err("failed reading file %s: %s", file, erro)
  end
  local data = handle.readAll()
  handle.close()
  local ok, erro = loadstr(data, "="..file)
  if not ok then
    err("failed loading file %s: %s", file, erro)
  end
  local ok, traceback = pcall(ok, fs.getDir(file))
  if not ok and traceback then
    err("failed executing file %s: %s", file, traceback)
  end
  os.shutdown()
  while true do coroutine.yield() end
end

local function checkFile(f)
  if fs.exists(f) then
    tprintf("Found %s - press any key within 0.5s to skip", f)
    local id = os.startTimer(f:sub(1,4) == "/rom" and 0 or 0.5)
    while true do
      local evt = coroutine.yield()
      if evt == "timer" then
        boot(f)
      elseif evt == "char" and f:sub(1,4) ~= "/rom" then
        tprintf("Skipping!")
        os.cancelTimer(id)
        break
      end
    end
  end
end

-- Load alternative software from disk, if it exists; otherwise load DoT-OS
-- from ROM
local locations = {
  "/disk",
  "/disk1",
  "/disk2",
  "/disk3",
  "/disk4",
  "/",
  "/rom"
}

for i, loc in ipairs(locations) do
  tprintf(" - checking %s for init.lua", loc)
  checkFile(fs.combine(loc, "init.lua"))
end

err("No boot file found!")
?? 
unbios.lua      ?-- UnBIOS by JackMacWindows
-- in this repository because i want to support as many versions of CC:T as possible
-- This will undo most of the changes/additions made in the BIOS, but some things may remain wrapped if `debug` is unavailable
-- To use, just place a `bios.lua` in the root of the drive, and run this program
-- Here's a list of things that are irreversibly changed:
-- * both `bit` and `bit32` are kept for compatibility
-- * string metatable blocking (on old versions of CC)
-- In addition, if `debug` is not available these things are also irreversibly changed:
-- * old Lua 5.1 `load` function (for loading from a function)
-- * `loadstring` prefixing (before CC:T 1.96.0)
-- * `http.request`
-- * `os.shutdown` and `os.reboot`
-- Licensed under the MIT license
if _HOST:find("UnBIOS") then return end
local keptAPIs = {bit32 = true, bit = true, ccemux = true, config = true, coroutine = true, debug = true, fs = true, http = true, io = true, mounter = true, os = true, periphemu = true, peripheral = true, redstone = true, rs = true, term = true, _HOST = true, _CC_DEFAULT_SETTINGS = true, _CC_DISABLE_LUA51_FEATURES = true, _VERSION = true, assert = true, collectgarbage = true, error = true, gcinfo = true, getfenv = true, getmetatable = true, ipairs = true, loadstring = true, math = true, newproxy = true, next = true, pairs = true, pcall = true, rawequal = true, rawget = true, rawlen = true, rawset = true, select = true, setfenv = true, setmetatable = true, string = true, table = true, tonumber = true, tostring = true, type = true, unpack = true, xpcall = true, turtle = true, pocket = true, commands = true, _G = true}
local t = {}
for k in pairs(_G) do if not keptAPIs[k] then table.insert(t, k) end end
for _,k in ipairs(t) do _G[k] = nil end
_G.term = _G.term.native()
_G.http.checkURL = _G.http.checkURLAsync
_G.http.websocket = _G.http.websocketAsync
local delete = {os = {"version", "pullEventRaw", "pullEvent", "run", "loadAPI", "unloadAPI", "sleep"}, http = {"get", "post", "put", "delete", "patch", "options", "head", "trace", "listen", "checkURLAsync", "websocketAsync"}, fs = {"complete", "isDriveRoot"}}
for k,v in pairs(delete) do for _,a in ipairs(v) do _G[k][a] = nil end end
_G._HOST = _G._HOST .. " (UnBIOS)"
-- Set up TLCO
-- This functions by crashing `rednet.run` by removing `os.pullEventRaw`. Normally
-- this would cause `parallel` to throw an error, but we replace `error` with an
-- empty placeholder to let it continue and return without throwing. This results
-- in the `pcall` returning successfully, preventing the error-displaying code
-- from running - essentially making it so that `os.shutdown` is called immediately
-- after the new BIOS exits.
--
-- From there, the setup code is placed in `term.native` since it's the first
-- thing called after `parallel` exits. This loads the new BIOS and prepares it
-- for execution. Finally, it overwrites `os.shutdown` with the new function to
-- allow it to be the last function called in the original BIOS, and returns.
-- From there execution continues, calling the `term.redirect` dummy, skipping
-- over the error-handling code (since `pcall` returned ok), and calling
-- `os.shutdown()`. The real `os.shutdown` is re-added, and the new BIOS is tail
-- called, which effectively makes it run as the main chunk.
local olderror = error
_G.error = function() end
_G.term.redirect = function() end
function _G.term.native()
    _G.term.native = nil
    _G.term.redirect = nil
    _G.error = olderror
    term.setBackgroundColor(32768)
    term.setTextColor(1)
    term.setCursorPos(1, 1)
    term.setCursorBlink(true)
    term.clear()
    local file = fs.open("/bios.lua", "r")
    if file == nil then
        term.setCursorBlink(false)
        term.setTextColor(16384)
        term.write("Could not find /bios.lua. UnBIOS cannot continue.")
        term.setCursorPos(1, 2)
        term.write("Press any key to continue")
        coroutine.yield("key")
        os.shutdown()
    end
    local fn, err = loadstring(file.readAll(), "@bios.lua")
    file.close()
    if fn == nil then
        term.setCursorBlink(false)
        term.setTextColor(16384)
        term.write("Could not load /bios.lua. UnBIOS cannot continue.")
        term.setCursorPos(1, 2)
        term.write(err)
        term.setCursorPos(1, 3)
        term.write("Press any key to continue")
        coroutine.yield("key")
        os.shutdown()
    end
    setfenv(fn, _G)
    local oldshutdown = os.shutdown
    os.shutdown = function()
        os.shutdown = oldshutdown
        return fn()
    end
end
if debug then
    -- Restore functions that were overwritten in the BIOS
    -- Apparently this has to be done *after* redefining term.native
    local function restoreValue(tab, idx, name, hint)
        local i, key, value = 1, debug.getupvalue(tab[idx], hint)
        while key ~= name and key ~= nil do
            key, value = debug.getupvalue(tab[idx], i)
            i=i+1
        end
        tab[idx] = value or tab[idx]
    end
    restoreValue(_G, "loadstring", "nativeloadstring", 1)
    restoreValue(_G, "load", "nativeload", 5)
    restoreValue(http, "request", "nativeHTTPRequest", 3)
    restoreValue(os, "shutdown", "nativeShutdown", 1)
    restoreValue(os, "reboot", "nativeReboot", 1)
    do
        local i, key, value = 1, debug.getupvalue(peripheral.isPresent, 2)
        while key ~= "native" and key ~= nil do
            key, value = debug.getupvalue(peripheral.isPresent, i)
            i=i+1
        end
        _G.peripheral = value or peripheral
    end
end
coroutine.yield()
?? dotos/apps/taskmgr.lua      ^-- task manager --

local dotos = require("dotos")
local dotui = require("dotui")
local colors = require("dotui.colors")

local window, base = dotui.util.basicWindow(2, 2, 30, 12, "Task Manager")

local taskmenu = dotui.Selector:new {
  x = 1, y = 1, w = window.w, h = 1, exclusive = true,
}

local scroll = dotui.Scrollable:new {
  x = 2, y = 3, w = window.w, h = base.h - 3,
  child = taskmenu
}

-- button bar at the top of the screen
local buttons = dotui.UIPage:new {
  x = 1, y = 1, w = window.w, h = 1,
  bg = colors.clickable_bg_default
}

local threads
base:addChild(buttons)
buttons:addChild(dotui.Clickable:new {
  x = 2, y = 1, w = 6, h = 1, text = " Kill ",
  callback = function()
    for k in pairs(taskmenu.selected) do
      if threads[k] then
        local answer = dotui.util.prompt("Really kill this process?",
          {"Yes", "No", title = "Confirmation"})
        if answer == "Yes" then
          dotos.kill(threads[k].id)
        end
        break
      end
    end
  end
})

local function buildTaskUI()
  taskmenu.items = {}
  threads = dotos.listthreads()
  taskmenu.h = #threads
  for i=1, #threads, 1 do
    taskmenu:addItem(string.format("%4d  %s", threads[i].id, threads[i].name))
  end
  taskmenu.surface:resize(taskmenu.w, taskmenu.h)
end

base:addChild(scroll)

dotui.util.genericWindowLoop(window, {generic = buildTaskUI})

dotos.exit()
?? dotos/apps/filemangler.lua      E-- the .OS file manager --

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
?? dotos/apps/settings.lua      6-- settings app --

local dotos = require("dotos")
local dotui = require("dotui")
local settings = require("settings")

local window, base = dotui.util.basicWindow(2, 2, 30, 12, "Settings")

local settingsTree = {
  keyboardLayout = {"lwjgl3", "lwjgl2",
    default = "lwjgl3", idefault = 1, name = "Keyboard Layout",
    type = 1},
  colorScheme = {"Light", "Dark", "Colorful", default = "Light", idefault = 1,
    name = "Color Scheme", type = 1},
  interface = {"dotui", "dotsh",
    default = "dotui", idefault = 1, name = "Interface", type = 1}
}

local settingsOrder = {
  "keyboardLayout", "colorScheme", "interface"
}

for k,v in pairs(settingsTree) do
  local sys = settings.sysget(k)
  if sys then
    v.default = sys
    for i=1, #v, 1 do
      if v[i] == sys then v.idefault = i break end
    end
  else
    settings.sysset(k, v.default)
  end
end

local y = 1
for i, set in ipairs(settingsOrder) do
  local k, v = set, settingsTree[set]
  y=y+1
  base:addChild(dotui.Label:new {
    x = 2, y = y, w = 18, h = 1,
    text = v.name
  })
  if v.type == 1 then
    v.dropdown = dotui.Dropdown:new {
      x = 20, y = y, w = 8, h = 5,
      items = v,
      text = v.default or "empty",
      selected = v.idefault or 1,
    }
  elseif v.type == 2 then
    v.dropdown = dotui.Switch:new{}
  end
end

-- add dropdowns separately so they get drawn on top
for i=#settingsOrder, 1, -1 do
  base:addChild(settingsTree[settingsOrder[i]].dropdown)
end

dotui.util.genericWindowLoop(window)

for k, v in pairs(settingsTree) do
  settings.sysset(k, v[v.dropdown.selected])
end

dotos.exit()
?? dotos/apps/demo.lua      	-- UI toolkit demo --

local dotos = require("dotos")
local dotui = require("dotui")
local colors = require("colors")

local window, base = dotui.util.basicWindow(2, 2, 30, 12, "UI Demo")

local long = dotui.UIPage:new {
  x = 1, y = 1, w = window.w, h = 41
}

local long2 = dotui.UIPage:new {
  x = 1, y = 1, w = window.w, h = 16
}

local text = [[
This is a demo of .OS's UI framework.

It supports word-wrapping, scrolling, and a host of other features.

Currently available controls are buttons, switches, sliders, and drop-downs:














Currently available apps are a task manager, system settings, a system log viewer, and this demo.  Clicking "Shut Down" in the menu presents a convenient shutdown dialog.

As you have probably noticed, scrollable views automatically render a scrollbar at their rightmost edge.
]]

local text2 = [[
This is a nested scrollable element.  Try scrolling it!

The desktop supports forcing windows into the background; this is how the desktop is drawn.  Try killing the 'desktop' process in the Task Manager.

As you can see, nested scrollable elements work as expected.
]]

long:addChild(dotui.Label:new {
  x = 2, y = 2, w = base.w - 4, h = 1, text = text, wrap = true
})

long2:addChild(dotui.Label:new {
  x = 1, y = 1, w = base.w - 6, h = 1, text = text2, wrap = true
})

long:addChild(dotui.Clickable:new {
  x = 2, y = 14, w = 9, h = 1, text = "Click Me!", callback = function()
    dotui.util.prompt("You clicked the button.", {"OK",
      title = "Oh, and prompts!"})
  end
})

long:addChild(dotui.Slider:new {
  x = 12, y = 16, w = 15, h = 1
})

long:addChild(dotui.Dropdown:new {
  x = 12, y = 14, w = 15, h = 5, items = {
    "Foo", "Bar", "Baz"
  }, selected = 1, text = "Select something"
})

local dynamictext = dotui.Label:new {
  x = 7, y = 16, w = 4, h = 1, text = "OFF",
  fg = colors.red
}

long:addChild(dotui.Switch:new {
  x = 2, y = 16, callback = function(self)
    if self.state then
      dynamictext.fg = colors.green
      dynamictext.text = "ON"
    else
      dynamictext.fg = colors.red
      dynamictext.text = "OFF"
    end
  end
})

long:addChild(dynamictext)

local scroll = dotui.Scrollable:new {
  x = 1, y = 1, w = window.w, h = base.h, child = long
}

local scroll2 = dotui.Scrollable:new {
  x = 3, y = 18, w = window.w - 4, h = 8, child = long2
}

long:addChild(scroll2)

base:addChild(scroll)

dotui.util.genericWindowLoop(window)

dotos.exit()
?? dotos/apps/syslog.lua      F-- view system logs --

local dotos = require("dotos")
local dotui = require("dotui")
local surface = require("surface")
local textutils = require("textutils")

local window, base = dotui.util.basicWindow(2, 2, 40, 14, "System Logs")

local logs = dotos.getlogs()
local logtext = dotui.Label:new {
  x = 1, y = 1, w = window.w, h = 1, text = "",
  wrap = true
}

local scroll = dotui.Scrollable:new {
  x = 1, y = 1, w = window.w, h = base.h,
  child = logtext,
}

local function buildLogUI()
  logtext.text = ""
  logtext.h = 0
  for i=1, #logs, 1 do
    logtext.text = logtext.text .. logs[i] .. "\n"
    logtext.h = logtext.h + #textutils.wordwrap(logs[i], window.w)
  end
  logtext.surface:resize(window.w, logtext.h)
end

buildLogUI()

base:addChild(scroll)
dotui.util.genericWindowLoop(window, {generic = buildLogUI})

dotos.exit()
?? dotos/motd.txt      ?{ORANGE} -- {YELLOW}DoT Shell {ORANGE} --

{RED}#{WHITE} For help type {BLUE}help{WHITE}.
{RED}#{WHITE} To return to the {RED}experimental{WHITE} DoT UI, run
  {BLUE}set interface dotui{WHITE}, then {BLUE}power -r{WHITE}.
{RED}#{WHITE} To see what commands are available, run
  {BLUE}list /dotos/binaries{WHITE}.
{RED}#{WHITE} To change this message, edit {YELLOW}/user/motd.txt{WHITE}.
?? "dotos/startup/01_init_settings.lua      9-- initialize the /.dotos.cfg file if it does not exist --

local fs = require("fs")

local defaultConfig = [[
colorScheme="Light"
interface="dotsh"
]]

if not fs.exists("/.dotos.cfg") then
  local handle = io.open("/.dotos.cfg", "w")
  if handle then
    handle:write(defaultConfig)
    handle:close()
  end
end
?? dotos/core/ifaced.lua      -- dynamically start/stop/suspend interfaces --

local dotos = require("dotos")
local ipc = require("ipc")

local path = "/dotos/interfaces/?/main.lua;/shared/interfaces/?/main.lua"

local running = {dynamic = dotos.getpid()}
local current
local api = {}

-- start an interface and switch to it
function api.start(_, iface)
  checkArg(1, iface, "string")
  if running[iface] then
    if current ~= iface then
      dotos.stop(running[current])
      dotos.continue(running[iface])
    end
    return true
  end

  local path = package.searchpath(iface, path)
  if not path then
    return nil, "Interface not found"
  end
  
  local pid = dotos.spawn(function()
    dofile(path)
  end, iface)
  running[iface] = pid
  
  if current then
    dotos.stop(running[current])
  end
  
  current = iface
  return true
end

-- stop an interface
function api.stop(_, iface)
  if not running[iface] then
    return nil, "That interface is not running"
  end
  if iface == "dynamic" then
    return nil, "Refusing to stop self"
  end
  dotos.kill(running[iface])
  running[iface] = nil
  return true
end

local configured = require("settings").sysget("interface") or "dotsh"
if configured == "dynamic" or not api.start(nil, configured) then
  api.start(nil, "dotsh")
end

dotos.handle("thread_died", function(_, pid)
  for k, v in pairs(running) do
    if pid == v then
      running[k] = nil
      dotos.log("INTERFACE CRASHED - STARTING dotsh")
      os.sleep(2)
      os.queueEvent("boy do i love hacks")
      api.start(nil, "dotsh")
    end
  end
end)

ipc.listen(api)
?? dotos/core/users.lua      r-- a proper user system --

local lib = {}

local dotos = require("dotos")
local fs = require("fs")
local settings = require("settings")
local hash = dofile("/dotos/core/sha256.lua").digest

local ucfg = "/.users.cfg"

local function ensure()
  if not fs.exists(ucfg) or not settings.get(ucfg, "admin") then
    settings.set(ucfg, "admin", tostring(hash("admin")))
  end
end

function lib.auth(name, pw)
  checkArg(1, name, "string")
  checkArg(2, pw, "string")
  if not lib.exists(name) then
    return nil, "that user does not exist"
  end
  return settings.get(ucfg, name) == tostring(hash(pw))
end

local threads = {}
function lib.threads(t)
  lib.threads = nil
  threads = t
end

function lib.runas(name, pw, ...)
  if not lib.auth(name, pw) then
    return nil, "bad credentials"
  end
  local old = dotos.getuser()
  local tid = dotos.getpid()
  threads[tid].user = name
  local result = table.pack(pcall(dotos.spawn, ...))
  threads[tid].user = old
  return assert(table.unpack(result, 1, result.n))
end

function lib.exists(name)
  checkArg(1, name, "string")
  ensure()
  return not not settings.get(ucfg, name)
end

return lib
?? dotos/core/essentials.lua      g-- some .OS core functions --

local dotos = require("dotos")

-- os library extensions --
function os.sleep(s)
  local tid = os.startTimer(s)
  repeat
    local sig, id = coroutine.yield()
  until sig == "timer" and id == tid
  return true
end

os.exit = dotos.exit
os.setenv = dotos.setenv
os.getenv = dotos.getenv

function os.version()
  return ".OS 0.1"
end

-- print()
function _G.print(...)
  local args = table.pack(...)
  local to_write = ""
  for i=1, args.n, 1 do
    if #to_write > 0 then to_write = to_write .. "\t" end
    to_write = to_write .. tostring(args[i])
  end
  io.write(to_write.."\n")
end
?? dotos/core/scheduler.lua      -- scheduler --

local users = dofile("/dotos/core/users.lua")
package.loaded.users = users
local fs = require("fs")
local dotos = require("dotos")

local threads = {}
local current = 0
local max = 0

local default_stream = {
  readAll = function() end,
  readLine = function() end,
  write = function(str) dotos.log(str) end,
  flush = function() end,
  seek = function() end,
  close = function() end,
}
default_stream = dotos.mkfile(default_stream, "rwb")
local default_thread = {io = {}, env = {TERM = "cynosure", HOME = "/"}}

function dotos.spawn(func, name, root)
  checkArg(1, func, "function")
  checkArg(2, name, "string")
  checkArg(3, root, "string", "nil")
  local parent = threads[current] or default_thread
  local nenv = {}
  if parent.env then
    for k,v in pairs(parent.env) do nenv[k] = v end
  end
  local thread = {
    coro = coroutine.create(func),
    env = nenv,
    io = {
      stdin = parent.io.stdin or default_stream,
      stdout = parent.io.stdout or default_stream,
      stderr = parent.io.stderr or default_stream,
    },
    pwd = parent.pwd or "/",
    root = root or parent.root or "/",
    name = name,
    user = parent.user or "admin",
  }
  max = max + 1
  threads[max] = thread
  return max
end

function dotos.getenv(k)
  if not k then return threads[current].env end
  checkArg(1, k, "string")
  return threads[current].env[k]
end

function dotos.setenv(k, v)
  checkArg(1, k, "string")
  threads[current].env[k] = v
end

function dotos.getpwd()
  return (threads[current] or default_thread).pwd
end

function dotos.setpwd(path)
  checkArg(1, path, "string")
  local t = threads[current] or default_thread
  if path:sub(1,1) ~= "/" then path = fs.combine(t.pwd, path) end
  if not fs.exists(path) then return nil, "no such file or directory" end
  if not fs.isDir(path) then return nil, "not a directory" end
  t.pwd = path
end

function dotos.getroot()
  return (threads[current] or default_thread).root
end

function dotos.getio(field)
  checkArg(1, field, "string")
  return (threads[current] or default_thread).io[field] or default_stream
end

function dotos.setio(field, file)
  checkArg(1, field, "string")
  checkArg(2, file, "table")
  local t = threads[current] or default_thread
  t.io[field] = file
  return true
end

function dotos.running(id)
  checkArg(1, id, "number")
  return not not threads[id]
end

function dotos.getpid()
  return current
end

function dotos.kill(id)
  checkArg(1, id, "number")
  threads[id] = nil
end

function dotos.getuser()
  return (threads[current] or default_thread).user
end

function dotos.setuser(name)
  checkArg(1, name, "string")
  if dotos.getuser() ~= "admin" then
    return nil, "permission denied"
  end
  if users.exists(name) then
    threads[current].user = name
    return true
  else
    return nil, "that user does not exist"
  end
end

users.threads(threads)

function dotos.listthreads()
  local t = {}
  for k,v in pairs(threads) do
    t[#t+1] = {id=k, name=v.name}
  end
  table.sort(t, function(a,b)
    return a.id < b.id
  end)
  return t
end

function dotos.stop(id)
  checkArg(1, id, "number")
  if not threads[id] then return nil, "no such thread" end
  threads[id].stopped = true
  return true
end

function dotos.continue(id)
  checkArg(1, id, "number")
  if not threads[id] then return nil, "no such thread" end
  threads[id].stopped = false
  return true
end

local handlers = {}
local hn = 0
function dotos.handle(sig, func, persist)
  checkArg(1, sig, "string")
  checkArg(2, func, "function")
  checkArg(3, persist, "boolean", "nil")
  hn = hn + 1
  handlers[hn] = {registrar = persist and 0 or current, sig = sig, func = func}
  return hn
end

function dotos.drop(n)
  checkArg(1, n, "number")
  handlers[n] = nil
  return true
end

local function deregister_handlers(id)
  for k, v in pairs(handlers) do
    if v.registrar == id then
      handlers[k] = nil
    end
  end
end

function dotos.exit()
  threads[current] = nil
  deregister_handlers(current)
  coroutine.yield()
end

local function loop()
  local lastTimerID
  while threads[1] do
    if not lastTimerID then
      lastTimerID = os.startTimer(0.5)
    end
    local signal = table.pack(coroutine.yield())
    if signal[1] == "timer" and signal[2] == lastTimerID then
      lastTimerID = nil
      signal = {n=0}
    end
    if signal.n > 0 then
      for i, handler in pairs(handlers) do
        if signal[1] == handler.sig then
          local ok, err = pcall(handler.func, table.unpack(signal, 1, signal.n))
          if not ok then
            dotos.log("signal handler error: " .. err)
          end
        end
      end
    end
    for k, v in pairs(threads) do
      if not v.stopped then
        current = k
        local ok, res = coroutine.resume(v.coro, table.unpack(signal, 1,
          signal.n))
        if not ok then
          dotos.log("[.os] thread %s failed: %s", k, res)
          deregister_handlers(v.id)
          os.queueEvent("thread_died", k, res)
          threads[k] = nil
        end
      end
    end
  end
  dotos.log("[.os] init thread has stopped")
  os.sleep(10)
  os.shutdown()
end

return loop
?? dotos/core/sha256.lua      ?-- SHA-256, HMAC and PBKDF2 functions in ComputerCraft
-- By Anavrins
-- MIT License
-- Pastebin: https://pastebin.com/6UV4qfNF
-- Usage: https://pastebin.com/q2SQ7eRg
-- Last updated: Nov 13 2021
 
local mod32 = 2^32
local band    = bit32 and bit32.band or bit.band
local bnot    = bit32 and bit32.bnot or bit.bnot
local bxor    = bit32 and bit32.bxor or bit.bxor
local blshift = bit32 and bit32.lshift or bit.blshift
local upack   = table.unpack
local unpack  = table.unpack
 
local function rrotate(n, b)
    local s = n/(2^b)
    local f = s%1
    return (s-f) + f*mod32
end
local function brshift(int, by)
    local s = int / (2^by)
    return s - s%1
end
 
local H = { -- First 32 bits of the fractional parts of the square roots of the first 8 primes 2..19
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
}
 
local K = { -- First 32 bits of the fractional parts of the cube roots of the first 64 primes 2..311
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}
 
local function counter(incr)
    local t1, t2 = 0, 0
    if 0xFFFFFFFF - t1 < incr then
        t2 = t2 + 1
        t1 = incr - (0xFFFFFFFF - t1) - 1       
    else t1 = t1 + incr
    end
    return t2, t1
end
 
local function BE_toInt(bs, i)
    return blshift((bs[i] or 0), 24) + blshift((bs[i+1] or 0), 16) + blshift((bs[i+2] or 0), 8) + (bs[i+3] or 0)
end
 
local function preprocess(data)
    local len = #data
    local proc = {}
    data[#data+1] = 0x80
    while #data%64~=56 do data[#data+1] = 0 end
    local blocks = math.ceil(#data/64)
    for i = 1, blocks do
        proc[i] = {}
        for j = 1, 16 do
            proc[i][j] = BE_toInt(data, 1+((i-1)*64)+((j-1)*4))
        end
    end
    proc[blocks][15], proc[blocks][16] = counter(len*8)
    return proc
end
 
local function digestblock(w, C)
    for j = 17, 64 do
        local v = w[j-15]
        local s0 = bxor(rrotate(w[j-15], 7), rrotate(w[j-15], 18), brshift(w[j-15], 3))
        local s1 = bxor(rrotate(w[j-2], 17), rrotate(w[j-2], 19),brshift(w[j-2], 10))
        w[j] = (w[j-16] + s0 + w[j-7] + s1)%mod32
    end
    local a, b, c, d, e, f, g, h = upack(C)
    for j = 1, 64 do
        local S1 = bxor(rrotate(e, 6), rrotate(e, 11), rrotate(e, 25))
        local ch = bxor(band(e, f), band(bnot(e), g))
        local temp1 = (h + S1 + ch + K[j] + w[j])%mod32
        local S0 = bxor(rrotate(a, 2), rrotate(a, 13), rrotate(a, 22))
        local maj = bxor(bxor(band(a, b), band(a, c)), band(b, c))
        local temp2 = (S0 + maj)%mod32
        h, g, f, e, d, c, b, a = g, f, e, (d+temp1)%mod32, c, b, a, (temp1+temp2)%mod32
    end
    C[1] = (C[1] + a)%mod32
    C[2] = (C[2] + b)%mod32
    C[3] = (C[3] + c)%mod32
    C[4] = (C[4] + d)%mod32
    C[5] = (C[5] + e)%mod32
    C[6] = (C[6] + f)%mod32
    C[7] = (C[7] + g)%mod32
    C[8] = (C[8] + h)%mod32
    return C
end
 
local mt = {
    __tostring = function(a) return string.char(unpack(a)) end,
    __index = {
        toHex = function(self, s) return ("%02x"):rep(#self):format(unpack(self)) end,
        isEqual = function(self, t)
            if type(t) ~= "table" then return false end
            if #self ~= #t then return false end
            local ret = 0
            for i = 1, #self do
                ret = bit32.bor(ret, bxor(self[i], t[i]))
            end
            return ret == 0
        end,
        sub = function(self, a, b)
            local len = #self+1
            local start = a%len
            local stop = (b or len-1)%len
            local ret = {}
            local i = 1
            for j = start, stop, start<stop and 1 or -1 do
                ret[i] = self[j]
                i = i+1
            end
            return setmetatable(ret, byteArray_mt)
        end,
    }
}
 
local function toBytes(t, n)
    local b = {}
    for i = 1, n do
        b[(i-1)*4+1] = band(brshift(t[i], 24), 0xFF)
        b[(i-1)*4+2] = band(brshift(t[i], 16), 0xFF)
        b[(i-1)*4+3] = band(brshift(t[i], 8), 0xFF)
        b[(i-1)*4+4] = band(t[i], 0xFF)
    end
    return setmetatable(b, mt)
end
 
local function digest(data)
    local data = data or ""
    data = type(data) == "table" and {upack(data)} or {tostring(data):byte(1,-1)}
 
    data = preprocess(data)
    local C = {upack(H)}
    for i = 1, #data do C = digestblock(data[i], C) end
    return toBytes(C, 8)
end
 
local function hmac(data, key)
    local data = type(data) == "table" and {upack(data)} or {tostring(data):byte(1,-1)}
    local key = type(key) == "table" and {upack(key)} or {tostring(key):byte(1,-1)}
 
    local blocksize = 64
 
    key = #key > blocksize and digest(key) or key
 
    local ipad = {}
    local opad = {}
    local padded_key = {}
 
    for i = 1, blocksize do
        ipad[i] = bxor(0x36, key[i] or 0)
        opad[i] = bxor(0x5C, key[i] or 0)
    end
 
    for i = 1, #data do
        ipad[blocksize+i] = data[i]
    end
 
    ipad = digest(ipad)
 
    for i = 1, blocksize do
        padded_key[i] = opad[i]
        padded_key[blocksize+i] = ipad[i]
    end
 
    return digest(padded_key)
end
 
local function pbkdf2(pass, salt, iter, dklen)
    local salt = type(salt) == "table" and salt or {tostring(salt):byte(1,-1)}
    local hashlen = 32
    local dklen = dklen or 32
    local block = 1
    local out = {}
 
    while dklen > 0 do
        local ikey = {}
        local isalt = {upack(salt)}
        local clen = dklen > hashlen and hashlen or dklen
 
        isalt[#isalt+1] = band(brshift(block, 24), 0xFF)
        isalt[#isalt+1] = band(brshift(block, 16), 0xFF)
        isalt[#isalt+1] = band(brshift(block, 8), 0xFF)
        isalt[#isalt+1] = band(block, 0xFF)
 
        for j = 1, iter do
            isalt = hmac(isalt, pass)
            for k = 1, clen do ikey[k] = bxor(isalt[k], ikey[k] or 0) end
            if j % 200 == 0 then os.queueEvent("PBKDF2", j) coroutine.yield("PBKDF2") end
        end
        dklen = dklen - clen
        block = block+1
        for k = 1, clen do out[#out+1] = ikey[k] end
    end
 
    return setmetatable(out, mt)
end

return {
    digest = digest,
    hmac   = hmac,
    pbkdf2 = pbkdf2,
}
?? dotos/libraries/splitters.lua      ?-- text splitters --

local lib = {}

-- simple gmatch splitter
function lib.simple(str, char)
  checkArg(1, str, "string")
  checkArg(2, char, "string")
  
  local res = {}

  for str in str:gmatch("[^"..char.."]+") do
    res[#res+1] = str
  end

  return res
end

-- shell-style splitter
function lib.complex(str)
  checkArg(1, str, "string")

  local res = {}
  local word, instr = "", false

  for c in str:gmatch(".") do
    if c == '"' then
      instr = not instr
    --  word = word .. c
    elseif instr then
      word = word .. c
    elseif c == " " then
      if #word > 0 then res[#res+1] = word end
      word = ""
    else
      word = word .. c
    end
  end
  if #word > 0 then res[#res+1] = word end

  return res
end

return lib
?? dotos/libraries/textutils.lua      -- textutils --

local lib = {}

lib.wordbreak = "[ %-=%+%*/%%]"

function lib.escape(text)
  checkArg(1, text, "string")
  return text:gsub("[%%%$%^%&%*%(%)%-%+%[%]%?%.]", "%%%1")
end

-- wrap text to the specified width
function lib.wrap(text, w)
  checkArg(1, text, "string")
  checkArg(2, w, "number")
  local lines = {""}
  local i = 1
  for c in text:gmatch(".") do
    if c == "\n" or #lines[i] >= w then
      i = i + 1
      lines[i] = ""
    end
    lines[i] = lines[i] .. c
  end
  return lines
end

-- split text into lines
function lib.lines(text)
  checkArg(1, text, "string")
  local lines = {""}
  for c in text:gmatch(".") do
    if c == "\n" then
      lines[#lines+1] = ""
    else
      lines[#lines] = lines[#lines] .. c
    end
  end
  if lines[#lines] == "" then lines[#lines] = nil end
  return lines
end

-- word-wrap text to the specified width
function lib.wordwrap(text, w)
  checkArg(1, text, "string")
  checkArg(2, w, "number")
  if #text < w then
    return {text}
  end
  local lines = {}
  for _, line in ipairs(lib.lines(text)) do
    if #line == 0 then
      lines[#lines+1] = ""
    else
      local startident = line:match("^ *") or ""
      while #line > 0 do
        local chunk = startident .. line:sub(1, w)
        if #chunk == w then
          local offset = chunk:reverse():find(lib.wordbreak) or 1
          chunk = chunk:sub(1, -offset)
        end
        line = line:sub(#chunk + 1 - #startident)
        lines[#lines+1] = chunk
      end
    end
  end
  return lines
end

function lib.padRight(text, w)
  checkArg(1, text, "string")
  checkArg(2, w, "number")
  return text .. (" "):rep(w - #text)
end

function lib.padLeft(text, w)
  checkArg(1, text, "string")
  checkArg(2, w, "number")
  return (" "):rep(w - #text) .. text
end

return lib
?? dotos/libraries/dotwm.lua      -- library for connection to .WM --

local ipc = require("ipc")

local lib = {}

function lib.connect()
  local channel, err = ipc.proxy(".wm")
  if not channel then return nil, err end
  local result, err = channel:connect()
  channel:close()
  return result
end

return lib
?? dotos/libraries/colors.lua      
s-- color constants --

local term = require("term")
local fs = require("fs")

-- the CraftOS color set is designed to match bundled cables, so provide
-- that set of colors here too
local bundled_order = {
  "white", "orange", "magenta", "lightBlue", "yellow",
  "lime", "pink", "gray", "lightGray", "cyan", "purple",
  "blue", "brown", "green", "red", "black"
}

--@docs {
--@header { Colors }
--Provides named constants for all the terminal's palette colors, plus some other useful functions.
--
--@header2 { Fields }
--@monospace { colors.bundled: @green { table } }
--  Provides all the CraftOS color constants for use with bundled cables, and bundled cables @italic { only }.
--
-- }
local colors = {}
colors.bundled = {}

colors.path = "/dotos/resources/palettes/?.lua;/user/resources/palettes/?.lua;/shared/resources/palettes/?.lua"

function colors.loadPalette(name)
  local palette, order
  if fs.exists(name) then
    palette, order = assert(loadfile(name, nil, {}))()
  else
    local file, err = package.searchpath(name, colors.path)
    if not file then
      return nil, err
    end
    palette, order = assert(loadfile(file, nil, {}))()
  end
  for i=1, 16, 1 do
    colors[order[i]] = 2^(i-1)
    term.setPaletteColor(colors[order[i]], palette[i])
  end
  return true
end

for i=1, 16, 1 do
  colors.bundled[bundled_order[i]] = 2^(i-1)
end

colors.loadPalette("default")

local blit_colors = {}
for i=1, 16, 1 do
  blit_colors[2^(i-1)] = string.format("%x", i - 1)
end

function colors.bundled.combine(...)
  local result = 0
  for i, color in ipairs(table.pack(...)) do
    checkArg(i, color, "number")
    result = bit32.bor(result, color)
  end
  return result
end

function colors.bundled.remove(combination, ...)
  checkArg(1, combination, "number")
  local result = combination
  for i, color in ipairs(table.pack(...)) do
    checkArg(i+1, color, "number")
    result = bit32.band(result, bit32.bnot(color))
  end
  return result
end

function colors.bundled.test(combination, color)
  checkArg(1, combination, "number")
  checkArg(2, color, "number")
  return bit32.band(combination, color) == color
end

function colors.toBlit(col)
  checkArg(1, col, "number")
  return blit_colors[col]
end

function colors.fromBlit(col)
  checkArg(1, col, "string")
  return 2^tonumber(col, 16)
end

function colors.pack(r, g, b)
  checkArg(1, r, "number")
  checkArg(2, g, "number")
  checkArg(3, b, "number")
  return r * 0x10000 + g * 0x100 + b
end

function colors.unpack(rgb)
  checkArg(1, rgb, "number")
  return
    bit32.rshift(bit32.band(rgb, 0xff0000), 16),
    bit32.rshift(bit32.band(rgb, 0x00ff00), 8),
    bit32.band(rgb, 0x0000ff)
end

return colors
?? dotos/libraries/dotsh.lua      a-- .SH: a simple shell (library-ified) --

local dotos = require("dotos")
local textutils = require("textutils")
local splitters = require("splitters")
local settings = require("settings")
local fs = require("fs")

local replacements = {
  ["{RED}"]    = "\27[91m",
  ["{WHITE}"]  = "\27[37m",
  ["{BLUE}"]   = "\27[94m",
  ["{YELLOW}"] = "\27[93m",
  ["{ORANGE}"] = "\27[33m",
  ["{GREEN}"]  = "\27[92m",
}

local shpath = settings.get("/.dotsh.cfg", "path") or
  "/dotos/binaries;/user/binaries;/shared/binaries"
settings.set("/.dotsh.cfg", "path", shpath)

local function check(path)
  if fs.exists(path) then
    return path
  elseif fs.exists(path..".lua") then
    return path..".lua"
  end
end

local lib = {}

local function resolve(cmd)
  if cmd:sub(1,2) == "./" then
    return check(fs.combine(dotos.getpwd(), (cmd:sub(2))))
  elseif cmd:find("/") then
    return check(cmd)
  else
    for ent in shpath:gmatch("[^;]+") do
      local res = check(fs.combine(ent, cmd))
      if res then return res end
    end
  end
  return nil, "command not found"
end
lib.resolve = resolve

local execute
local builtins = {
  resolve = function(c, path)
    local res, err = resolve(path)
    if not res then error("resolution error: " .. err, 0) end
    if c then return res else print(res) return true end
  end,
  cd = function(c, dir)
    dir = dir or "/user"
    local ok, err = dotos.setpwd(dir)
    if not ok and err then error(err, 0) end
    return c and "" or ok
  end,
  pwd = function(c)
    if c then return dotos.getpwd() else print(dotos.getpwd()) end
  end,
  exit = function() dotos.exit() end,
  chuser = function(_, name)
    local ok, err = dotos.setuser(name)
    if not ok and err then error(err, 0) end
    return true
  end,
  echo = function(c, ...)
    local text = table.concat(table.pack(...), " ")
    if c then return text else print(text) end
  end,
  source = function(c, file, ...)
    local args = {...}
    return execute("{.cat " .. file .. "}", c, {...})
  end
}

local aliases = {
  ls = "list",
  rm = "delete",
  edit = "tle"
}

execute = function(input, capture, positional)
  if #input == 0 then return end
  local tokens = splitters.complex(input)
  local cmd = tokens[1]
  if aliases[cmd] then cmd = aliases[cmd] end
  if builtins[cmd] then
    return builtins[cmd](capture, table.unpack(tokens, 2, tokens.n))
  else
    local cmd, err = resolve(cmd)
    if not cmd then error(err, 0) end
    local cap, err = ""
    local id = dotos.spawn(function()
      local yield = coroutine.yield
      if capture then
        io.output(
          dotos.mkfile({
            read = function() end,
            readLine = function() end,
            readAll = function() end,
            write = function(str) cap = cap .. str end,
            flush = function() end,
            close = function() end
          }, "w"))
      end
      if positional then
        for i=1, #positional, 1 do
          os.setenv(tostring(i), positional[i])
        end
      end
      local function wrapped_yield(...)
        coroutine.yield = yield
        local result = table.pack(yield(...))
        coroutine.yield = wrapped_yield
        if result[1] == "terminate" then
          error("terminated", 0)
        end
        return table.unpack(result, 1, result.n)
      end
      coroutine.yield = wrapped_yield
      local ok, res = pcall(dofile, cmd, table.unpack(tokens, 2, tokens.n))
      if not ok then err = res end
      dotos.exit()
    end, input)
    while dotos.running(id) do coroutine.yield() end
    if err then error(err, 0) end
    if capture then return cap else return true end
  end
end
lib.execute = execute

-- fancy syntax
setmetatable(replacements, {__index = function(_, k)
  replacements[k] = function()
    replacements[k] = nil
    k = k:sub(2, -2) -- strip outer {}
    if k:sub(1,1) == "." then
      -- {.cmd bla}: execute command and return its output, like bash's $(cmd).
      if k:sub(2,2) == ">" or k:sub(2,2) == "+" then
        -- {.>file cmd bla}: execute command and put its output into 'file',
        --   like unix shells' cmd bla > file
        -- {.+file cmd bla}: do this and still return the output, similar to
        --   the 'tee' command
        local fsp = k:find(" ")
        if not fsp then return "" end
        local file = k:sub(3, fsp - 1)
        local output = execute(k:sub(fsp+1), true)
        local handle, err = io.open(file, "w")
        if not handle then error(err, 0) end
        handle:write(output)
        handle:close()
        return ""
      --[[ these will probably be supported in the future
      elseif k:sub(2,2) == "<" then
        -- {.<file cmd bla}: execute command and put its standard input as
        --   'file'
      elseif k:sub(2,2) == "|" then
        -- {.|foo bar; baz bla}: pipe commands]]
      else
        return execute(k:sub(2), true)
      end
    elseif k:sub(1,1) == "$" then
      -- {$VAR}: get environment variable
      if k:sub(2,2) == "@" or k:sub(2,2) == "+" then
        -- {$@VAR=VAL}: set environment variable
        -- {$+VAR=VAL}: set environment variable *and* return VAL
        local key, val = k:match("^%$.(.-)=(.+)")
        os.setenv(key, val)
        if k:sub(2,2) == "+" then
          return val
        end
        return ""
      elseif k:sub(2,2) == "!" then
        -- {$!VAR}: unset environment variable
        os.setenv(k:sub(3), nil)
      elseif k:sub(2,2) == "?" then
        -- {$?}: all environment variables
        local env = os.getenv()
        local lines = {}
        for k,v in pairs(env) do
          lines[#lines+1] = k .. "=" .. v
        end
        table.sort(lines)
        return table.concat(lines, "\n")
      else
        return os.getenv(k:sub(2)) or ""
      end
      return ""
    end
  end
  return replacements[k]
end})

function lib.expand(input)
  input = input:gsub("%b{}", function(k)
      if type(replacements[k]) == "function" then
        return replacements[k]()
      else
        return replacements[k] or k
      end
    end)
  input = input:gsub("%b{}", function(k)
      if type(replacements[k]) == "function" then
        return replacements[k]()
      else
        return replacements[k] or k
      end
    end)
  return input
end

return lib
?? dotos/libraries/iostream.lua      ?-- iostream: Create an IO stream from a surface --
-- allows terminals and whatnot --

local dotos = require("dotos")
local vt = require("vt100")

local lib = {}

function lib.wrap(surface)
  checkArg(1, surface, "table")
  local s = {}

  function s.read(n)
    checkArg(1, n, "number")
    return s.vt:read(n)
  end

  function s.readLine(keepnl)
    keepnl = not not keepnl
    return s.vt:readline(keepnl)
  end

  function s.readAll()
    return s.vt:read(math.huge)
  end

  function s.write(str)
    return s.vt:write(str)
  end

  function s.flush()
    return s.vt:flush()
  end

  function s.close()
    return s.vt:close()
  end

  s.vt = vt.new(surface)
  return dotos.mkfile(s, "rw")
end

return lib
?? dotos/libraries/termio.lua      
!-- terminal I/O library --

local lib = {}

local function getHandler()
  local term = os.getenv("TERM") or "generic"
  return require("termio."..term)
end

-------------- Cursor manipulation ---------------
function lib.setCursor(x, y)
  if not getHandler().ttyOut() then
    return
  end
  io.write(string.format("\27[%d;%dH", y, x))
end

function lib.getCursor()
  if not (getHandler().ttyIn() and getHandler().ttyOut()) then
    return 1, 1
  end

  io.write("\27[6n")
  
  getHandler().setRaw(true)
  local resp = ""
  
  repeat
    local c = io.read(1)
    resp = resp .. c
  until c == "R"

  getHandler().setRaw(false)
  local y, x = resp:match("\27%[(%d+);(%d+)R")

  return tonumber(x), tonumber(y)
end

function lib.getTermSize()
  local cx, cy = lib.getCursor()
  lib.setCursor(9999, 9999)
  
  local w, h = lib.getCursor()
  lib.setCursor(cx, cy)

  return w, h
end

function lib.cursorVisible(vis)
  getHandler().cursorVisible(vis)
end

----------------- Keyboard input -----------------
local patterns = {}

local substitutions = {
  A = "up",
  B = "down",
  C = "right",
  D = "left",
  ["5"] = "pageUp",
  ["6"] = "pageDown"
}

-- string.unpack isn't a thing in 1.12.2's CC:T 1.89.2, so use this instead
-- because this is all we need
local function strunpack(str)
  local result = 0
  for c in str:reverse():gmatch(".") do
    result = bit32.lshift(result, 8) + c:byte()
  end
  return result
end

local function getChar(char)
  local byte = strunpack(char)
  if byte + 96 > 255 then
    return utf8.char(byte)
  end
  return string.char(96 + byte)
end

function lib.readKey()
  getHandler().setRaw(true)
  local data = io.stdin:read(1)
  local key, flags
  flags = {}

  if data == "\27" then
    local intermediate = io.stdin:read(1)
    if intermediate == "[" then
      data = ""

      repeat
        local c = io.stdin:read(1)
        data = data .. c
        if c:match("[a-zA-Z]") then
          key = c
        end
      until c:match("[a-zA-Z]")

      flags = {}

      for pat, keys in pairs(patterns) do
        if data:match(pat) then
          flags = keys
        end
      end

      key = substitutions[key] or "unknown"
    else
      key = io.stdin:read(1)
      flags = {alt = true}
    end
  elseif data:byte() > 31 and data:byte() < 127 then
    key = data
  elseif data:byte() == (getHandler().keyBackspace or 127) then
    key = "backspace"
  elseif data:byte() == (getHandler().keyDelete or 8) then
    key = "delete"
  else
    key = getChar(data)
    flags = {ctrl = true}
  end

  getHandler().setRaw(false)

  return key, flags
end

return lib
?? dotos/libraries/state.lua      s-- state saving for saving state across service restarts and whatnot --
-- this is NOT for saving state across reboots

local dotos = require("dotos")

local lib = {}

local states = {}

function lib.create(id)
  if id == nil then
    error("bad argument #1 (expected value, got nil)")
  end
  states[id] = states[id] or {}
  if states[id].creator and states[id].creator ~= dotos.getpid()
      and dotos.running(states[id].creator) then
    return nil, "cannot claim another process's state"
  end
  states[id].creator = dotos.getpid()
  return states[id]
end

function lib.discard(id)
  if id == nil then
    error("bad argument #1 (expected value, got nil)")
  end
  local s = states[id]
  if not s then return true end
  if s.creator and dotos.running(s.creator) and s.creator ~= dotos.getpid() then
    return nil, "cannot discard another process's state"
  end
end

return lib
?? dotos/libraries/sizes.lua      -- size formatting --

local lib = {}

local exts = {
  "", "K", "M", "G", "T"
}

function lib.formatSized(num, div)
  checkArg(1, num, "number")
  checkArg(2, div, "number")
  local i = 1
  while num > div do
    num = num / div
    i = i + 1
  end
  return string.format("%.2f%s", num, exts[i])
end

function lib.format1024(num)
  checkArg(1, num, "number")
  return lib.formatSized(num, 1024)
end

function lib.format1000(num)
  checkArg(1, num, "number")
  return lib.formatSized(num, 1000)
end

lib.format = lib.format1024

return lib
?? dotos/libraries/sigtypes.lua      H-- rough signal type classifications --

local types = {}

types.mouse = {
  mouse_scroll = true,
  mouse_click = true,
  mouse_drag = true,
  mouse_up = true,
}

types.click = {
  mouse_click = true,
  monitor_touch = true
}

types.keyboard = {
  clipboard = true,
  key_up = true,
  char = true,
  key = true,
}

return types
?? #dotos/libraries/termio/cynosure.lua      ?-- handler for the Cynosure terminal

local handler = {}

handler.keyBackspace = 8

function handler.setRaw(raw)
  if raw then
    io.write("\27?3;12c\27[8m")
  else
    io.write("\27?13;2c\27[28m")
  end
end

function handler.cursorVisible(v)
  io.write(v and "\27?4c" or "\27?14c")
end

function handler.ttyIn()
  return not not io.input().tty
end

function handler.ttyOut()
  return not not io.output().tty
end

return handler
?? )dotos/libraries/termio/xterm-256color.lua      ?-- xterm-256color handler --

local handler = {}

local termio = require("posix.termio")
local isatty = require("posix.unistd").isatty

handler.keyBackspace = 127
handler.keyDelete = 8

local default = termio.tcgetattr(0)
local raw = {}
for k,v in pairs(default) do raw[k] = v end
raw.oflag = 4
raw.iflag = 0
raw.lflag = 35376
default.cc[2] = handler.keyBackspace

function handler.setRaw(_raw)
  if _raw then
    termio.tcsetattr(0, termio.TCSANOW, raw)
  else
    termio.tcsetattr(0, termio.TCSANOW, default)
  end
end

function handler.cursorVisible(v)
  
end

function handler.ttyIn() return isatty(0) == 1 end
function handler.ttyOut() return isatty(1) == 1 end

return handler
?? dotos/libraries/settings.lua      Y-- settings management --

local fs = require("fs")

local function serialize(k, v)
  checkArg(1, k, "string")
  checkArg(2, v, "string", "number", "boolean", "nil")
  return string.format("%s=%q\n", k, v)
end

local function coerce(k)
  if k == "true" then return true end
  if k == "false" then return false end
  if k == "nil" then return nil end
  if k:sub(1,1) == '"' then k = k:sub(2,-2) end
  return tonumber(k) or k
end

local function unserialize(line)
  local k, v = line:match("(.-)=(.+)")
  return k, coerce(v)
end

local lib = {}

function lib.load(file)
  checkArg(1, file, "string")
  local handle, err = io.open(file, "r")
  if not handle then return {}, err end
  local cfg = {}
  for line in handle:lines() do
    local k, v = unserialize(line)
    if k and v then cfg[k] = v end
  end
  handle:close()
  return cfg
end

function lib.save(file, cfg)
  checkArg(1, file, "string")
  checkArg(2, cfg, "table")
  local handle = assert(io.open(file, "w"))
  for k,v in pairs(cfg) do
    handle:write(serialize(k,v))
  end
  handle:close()
end

if fs.isReadOnly("/") then
  local files = {}
  function lib.get(file, k)
    return (files[file] or {})[k]
  end

  function lib.set(file, k, v)
    files[file] = files[file] or {}
    files[file][k] = v
  end
else
  function lib.get(file, k)
    return lib.load(file)[k]
  end

  function lib.set(file, k, v)
    local c = lib.load(file)
    c[k] = v
    lib.save(file, c)
  end
end

-- system settings functions
local file = "/.dotos.cfg"
function lib.sysget(k)
  return lib.get(file, k)
end

function lib.sysset(k, v)
  return lib.set(file, k, v)
end

return lib
?? dotos/libraries/advmath.lua       ?-- additional mathematical functions --

local lib = {}

-- linear interpolation
function lib.lerp(start, finish, duration, elapsed)
  return start + (finish - start) * (math.min(duration, elapsed) / duration)
end

return lib
?? dotos/libraries/readline.lua      ?-- a readline library --

local termio = require("termio")

local rlid = 0

local function readline(opts)
  checkArg(1, opts, "table", "nil")
  
  local uid = rlid + 1
  rlid = uid
  opts = opts or {}
  if opts.prompt then io.write(opts.prompt) end

  local history = opts.history or {}
  history[#history+1] = ""
  local hidx = #history
  
  local buffer = ""
  local cpos = 0

  local w, h = termio.getTermSize()
  
  while true do
    local key, flags = termio.readKey()
    flags = flags or {}
    if not (flags.ctrl or flags.alt) then
      if key == "up" then
        if hidx > 1 then
          if hidx == #history then
            history[#history] = buffer
          end
          hidx = hidx - 1
          local olen = #buffer - cpos
          cpos = 0
          buffer = history[hidx]
          if olen > 0 then io.write(string.format("\27[%dD", olen)) end
          local cx, cy = termio.getCursor()
          if cy < h then
            io.write(string.format("\27[K\27[B\27[J\27[A%s", buffer))
          else
            io.write(string.format("\27[K%s", buffer))
          end
        end
      elseif key == "down" then
        if hidx < #history then
          hidx = hidx + 1
          local olen = #buffer - cpos
          cpos = 0
          buffer = history[hidx]
          if olen > 0 then io.write(string.format("\27[%dD", olen)) end
          local cx, cy = termio.getCursor()
          if cy < h then
            io.write(string.format("\27[K\27[B\27[J\27[A%s", buffer))
          else
            io.write(string.format("\27[K%s", buffer))
          end
        end
      elseif key == "left" then
        if cpos < #buffer then
          cpos = cpos + 1
          io.write("\27[D")
        end
      elseif key == "right" then
        if cpos > 0 then
          cpos = cpos - 1
          io.write("\27[C")
        end
      elseif key == "backspace" then
        if cpos == 0 and #buffer > 0 then
          buffer = buffer:sub(1, -2)
          io.write("\27[D \27[D")
        elseif cpos < #buffer then
          buffer = buffer:sub(0, #buffer - cpos - 1) ..
            buffer:sub(#buffer - cpos + 1)
          local tw = buffer:sub((#buffer - cpos) + 1)
          io.write(string.format("\27[D%s \27[%dD", tw, cpos + 1))
        end
      elseif #key == 1 then
        local wr = true
        if cpos == 0 then
          buffer = buffer .. key
          io.write(key)
          wr = false
        elseif cpos == #buffer then
          buffer = key .. buffer
        else
          buffer = buffer:sub(1, #buffer - cpos) .. key ..
            buffer:sub(#buffer - cpos + 1)
        end
        if wr then
          local tw = buffer:sub(#buffer - cpos)
          io.write(string.format("%s\27[%dD", tw, #tw - 1))
        end
      end
    elseif flags.ctrl then
      if key == "m" then -- enter
        if cpos > 0 then io.write(string.format("\27[%dC", cpos)) end
        io.write("\n")
        break
      elseif key == "a" and cpos < #buffer then
        io.write(string.format("\27[%dD", #buffer - cpos))
        cpos = #buffer
      elseif key == "e" and cpos > 0 then
        io.write(string.format("\27[%dC", cpos))
        cpos = 0
      elseif key == "d" and not opts.noexit then
        io.write("\n")
        ; -- this is a weird lua quirk
        (type(opts.exit) == "function" and opts.exit or os.exit)()
      elseif key == "i" then -- tab
        if type(opts.complete) == "function" and cpos == 0 then
          local obuffer = buffer
          buffer = opts.complete(buffer, rlid) or buffer
          if obuffer ~= buffer and #obuffer > 0 then
            io.write(string.format("\27[%dD", #obuffer - cpos))
            cpos = 0
            local cx, cy = termio.getCursor()
            if cy < h then
              io.write(string.format("\27[K\27[B\27[J\27[A%s", buffer))
            else
              io.write(string.format("\27[K%s", buffer))
            end
          end
        end
      end
    end
  end

  history[#history] = nil
  return buffer
end

return readline
?? dotos/libraries/surface.lua      ?-- This API is similar to the Window api provided by CraftOS, but:
--   - it does not attempt to provide an API similar to term,
--     instead preferring a custom set of commands
--   - it uses proper object-orientation rather than...
--     whatever it is the Window api does

local term = require("term")
local colors = require("colors")

local s = {}

local function into_buffer(buf, x, y, text, xoff)
  if not text then return end
  if not buf[y] then return end
  xoff = xoff or 0
  text = text:sub(xoff + 1)
  text = text:sub(1, #buf[y] - x + 1)
  if x < 1 then
    text = text:sub(-x + 2)
    x = 1
  end
  local olen = #buf[y]
  buf[y] = (buf[y]:sub(0, math.max(0,x-1)) .. text .. buf[y]:sub(x + #text))
    :sub(1, olen)
end

function s:blit(parent, x, y, xoff, yoff)
  checkArg(1, parent, "table")
  checkArg(2, x, "number")
  checkArg(3, y, "number")
  checkArg(4, xoff, "number", "nil")
  checkArg(5, yoff, "number", "nil")
  xoff = xoff or 0
  yoff = yoff or 0
  if y < 0 then
    yoff = -y + 1
    y = 1
  end
  for i=1, self.h, 1 do
    into_buffer(parent.buffer_fg, x, y + i - 1,
      self.buffer_fg[i + yoff], xoff)
    into_buffer(parent.buffer_bg, x, y + i - 1,
      self.buffer_bg[i + yoff], xoff)
    into_buffer(parent.buffer_text, x, y + i - 1,
      self.buffer_text[i + yoff], xoff)
  end
  return self
end

function s:draw(x, y)
  checkArg(1, x, "number")
  checkArg(2, y, "number")
  for i=1, self.h, 1 do
    term.setCursorPos(x, y + i - 1)
    term.blit(self.buffer_text[i], self.buffer_fg[i], self.buffer_bg[i])
  end
  return self
end

function s:fill(x, y, w, h, ch, fg, bg)
  checkArg(1, x, "number")
  checkArg(2, y, "number")
  checkArg(3, w, "number")
  checkArg(4, h, "number")
  checkArg(5, ch, "string", "nil")
  checkArg(6, fg, "number", self.foreground and "nil")
  checkArg(7, bg, "number", self.background and "nil")
  self.foreground = fg or self.foreground
  self.background = bg or self.background
  if w == 0 or h == 0 then return self end
  ch = (ch or " "):sub(1,1):rep(w)
  fg = colors.toBlit(self.foreground):rep(w)
  bg = colors.toBlit(self.background):rep(w)
  for i=1, h, 1 do
    into_buffer(self.buffer_text, x, y + i - 1, ch)
    into_buffer(self.buffer_fg, x, y + i - 1, fg)
    into_buffer(self.buffer_bg, x, y + i - 1, bg)
  end
  return self
end

function s:set(x, y, str, fg, bg)
  checkArg(1, x, "number")
  checkArg(2, y, "number")
  checkArg(3, str, "string")
  checkArg(4, fg, "number", self.foreground and "nil")
  checkArg(5, bg, "number", self.background and "nil")
  self.foreground = fg or self.foreground
  self.background = bg or self.background
  if #str == 0 then return self end
  fg = colors.toBlit(fg or self.foreground):rep(#str)
  bg = colors.toBlit(bg or self.background):rep(#str)
  into_buffer(self.buffer_text, x, y, str)
  into_buffer(self.buffer_fg, x, y, fg)
  into_buffer(self.buffer_bg, x, y, bg)
  return self
end

function s:rawset(x, y, str, fg, bg)
  checkArg(1, x, "number")
  checkArg(2, y, "number")
  checkArg(3, str, "string")
  checkArg(4, fg, "string")
  checkArg(5, bg, "string")
  assert(#str == #fg and #str == #bg, "mismatched argument lengths")
  into_buffer(self.buffer_text, x, y, str)
  into_buffer(self.buffer_fg, x, y, fg)
  into_buffer(self.buffer_bg, x, y, bg)
  return self
end

function s:get(x, y, len)
  checkArg(1, x, "number")
  checkArg(2, y, "number")
  checkArg(3, len, "number")
  local text = self.buffer_text[y]:sub(x, x + len - 1)
  local fg = self.buffer_fg[y]:sub(x, x + len - 1)
  local bg = self.buffer_bg[y]:sub(x, x + len - 1)
  return text, fg, bg
end

function s:fg(col)
  checkArg(1, col, "number", "nil")
  if col then self.foreground = col return self end
  return self.foreground
end

function s:bg(col)
  checkArg(1, col, "number", "nil")
  if col then self.background = col return self end
  return self.background
end

local function expand_buffer(self, buf, nw, nh)
  if nh > self.h then
    for i=1, nh - self.h, 1 do
      buf[#buf+1] = buf[#buf]
    end
  end
  if nw > self.w then
    for i=1, #buf, 1 do
      buf[i] = buf[i] .. buf[i]:sub(-1):rep(nw - self.w)
    end
  end
end

function s:resize(w, h)
  checkArg(1, w, "number")
  checkArg(2, h, "number")
  expand_buffer(self, self.buffer_text, w, h)
  expand_buffer(self, self.buffer_fg, w, h)
  expand_buffer(self, self.buffer_bg, w, h)
  self.w = w
  self.h = h
end

local surf = {}

function surf.new(w, h)
  checkArg(1, w, "number")
  checkArg(2, h, "number")
  local new = setmetatable({
    buffer_fg = {},
    buffer_bg = {},
    buffer_text = {},
    w = w, h = h
  }, {__index = s, __metatable = {}})
  local zero = string.rep("0", w)
  local blank = string.rep(" ", w)
  for i=1, h, 1 do
    new.buffer_fg[i] = zero
    new.buffer_bg[i] = zero
    new.buffer_text[i] = blank
  end
  return new
end

return surf
?? dotos/libraries/dotui.lua      B?-- .UI --

local dotos = require("dotos")
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
    for k=#self.children, 1, -1 do
      local child = self.children[k]
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
  checkArg("h", args.h, "number")
  checkArg("fg", args.fg, "number")
  checkArg("bg", args.bg, "number")
  if needsText then
    checkArg("text", args.text, "string")
  else
    checkArg("text", args.text, "string", "nil")
  end
  if args.text then
    args.w = args.w or #args.text
  end
  checkArg("w", args.w, "number")
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
  checkArg("child", args.child, "table")
  self.scrollX = 0
  self.scrollY = 0
  self.drawsurface = surf.new(self.w, self.h)
  self.child = args.child
  self.child.surface = self.child.surface or
    surf.new(self.child.w - 1, self.child.h)
end

function lib.Scrollable:draw(xoff, yoff)
  -- render child
  self.child:draw()
  local x, y, w, h = computeCoordinates(self, xoff, yoff)
  -- blit surface
  self.surface:fill(x, y, w, h, " ", self.fcolor, self.bcolor)
  self.drawsurface:fill(1, 1, self.drawsurface.w, self.drawsurface.h, " ",
    self.fcolor, self.bcolor)
  self.child.surface:blit(self.drawsurface, -self.scrollX + 1,
    -self.scrollY + 1)
  self.drawsurface:blit(self.surface, x, y)
  -- draw scrollbar
  self.surface:fill(w, y, 1, h, "\127", colorscheme.scrollbar_fg,
    colorscheme.scrollbar_color)
  local sb_y = math.floor(
    (h - 1) * (self.scrollY / (self.child.surface.h - h)))
  self.surface:set(w, y + sb_y, " ", colorscheme.scrollbar_color,
    colorscheme.scrollbar_fg)
end

function lib.Scrollable:find(x, y, fscr)
  local element
  if x >= self.child.x and y >= self.child.y and
      x < self.child.x + self.child.w and y < self.child.y + self.child.h then
    element = self.child:find(x + self.scrollX,
      y + self.scrollY, fscr)
  end
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
  args.w = 3
  args.h = 1
  local call = args.callback
  function args.callback(self)
    self.state = not self.state
    if call then call(self) end
  end
  lib.Clickable.init(self, args)
end

function lib.Switch:draw(xoff, yoff)
  local x, y, w, h = computeCoordinates(self, xoff, yoff)
  self.surface:fill(x, y, w, h, " ", self.fcolor,
    self.state and colorscheme.switch_on or colorscheme.switch_off)
  if not self.state then
    self.surface:set(x, y, " ", nil, colors.lightGray)
  else
    self.surface:set(x + 2, y, " ", nil, colors.lightGray)
  end
end

lib.Slider = lib.UIElement:new()
function lib.Slider:init(args)
  if args then
    args.fg = args.fg or colorscheme.accent_color
    args.bg = args.bg or colorscheme.bg_default
  end
  base_init(self, args)
  args.max = args.max or 100
  args.min = args.min or 0
  checkArg("max", args.max, "number")
  checkArg("min", args.min, "number")
  self.max = args.max
  self.min = args.min
  self.pos = 1
end

function lib.Slider:find(x, y, fscr)
  if fscr then return end
  self.pos = x
  self.value = math.floor((self.max - self.min) * (self.pos / self.w))
end

function lib.Slider:draw(xoff, yoff)
  local x, y, w, h = computeCoordinates(self, xoff, yoff)
  self.surface:fill(x, y, w, 1, "\140", self.fcolor, self.bcolor)
  self.surface:set(x + self.pos - 1, y, " ", colorscheme.bg_default,
    colorscheme.clickable_bg_default)
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
    x = 2, y = self.items, w = self.surface.w, h = 1,
    text = string.rep("\140", self.surface.w - 2),
    fg = self.fcolor, bg = self.bcolor
  }
  self:addChild(obj)
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
  checkArg("callbacks", args.callbacks, "table", "nil")
  args.fg = args.fg or colorscheme.dropdown_text_default
  args.bg = args.bg or colorscheme.dropdown_bg_default
  base_init(self, args)
  self.items = args.items or {}
  self.selected = args.selected or 0
  self.menuHidden = true
  self.button = 1
  self.callback = function(self)
    local y = self.lastY
    if y == 1 then
      self.menuHidden = not self.menuHidden
    elseif not self.menuHidden then
      local i = y - 1
      self.selected = i
      if self.callbacks[i] then self.callbacks[i](self)
      else self.text = self.items[self.selected] or self.text end
      self.menuHidden = true
    end
  end
  self.callbacks = args.callbacks or {}
end

function lib.Dropdown:addItem(text)
  checkArg(1, text, "string")
  self.items[#self.items+1] = text
end

function lib.Dropdown:draw(xoff, yoff)
  local x, y, w, h = computeCoordinates(self, xoff, yoff)
  if not self.hideArrow then
    self.surface:set(x, y, textutils.padRight(self.text or "Select something",
      self.w - 2):sub(1, self.w - 2) .. (self.menuHidden and " \31" or " \30"),
      self.fcolor, self.bcolor)
  else
    self.surface:set(x, y, textutils.padRight(self.text or "Select something",
      self.w):sub(1, self.w), self.fcolor, self.bcolor)
  end
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
  self.lastY = y
  if self.menuHidden then
    if y == 1 then return self end
  else
    return self
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
  local lastDragX, lastDragY
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
        if signal[4] == 1 then -- dragging in titlebar
          win.dragging = true
        else
          local element = win:find(signal[3], signal[4])
          if element and element.drag then
            element:drag(sdx, sdy)
          end
        end
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
  window.keepOnTop = true
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
?? dotos/libraries/io.lua      -- io library --

local osPath = ...
-- package.lua nils this later but hasn't done so yet because it depends on io
local dotos = dotos

-- the package library nils _G.fs later, so keep it here
local fs = fs

-- split a file path into segments
local function split(path)
  local s = {}
  for S in path:gmatch("[^/\\]+") do
    if S == ".." then
      s[#s] = nil
    elseif S ~= "." then
      s[#s+1] = S
    end
  end
  return s
end

-- override the fs library to use this resolution function where necessary
do
  -- path resolution:
  -- if the path begins with /dotos, then redirect to wherever that actually
  -- is; otherwise, resolve the path based on the current program's working
  -- directory
  -- this is to allow .OS to run from anywhere
  local function resolve(path)
    local root = (dotos.getroot and dotos.getroot()) or "/"
    local pwd = (dotos.getpwd and dotos.getpwd()) or "/"
    if path:sub(1,1) ~= "/" then
      path = fs.combine(pwd, path)
    end
    path = fs.combine(root, path)
    local segments = split(path)
    if segments[1] == "dotos" then
      return fs.combine(osPath, path)
    elseif segments[1] == "user" then
      return fs.combine("/users",
        (dotos.getuser and dotos.getuser()) or "admin",
        table.concat(segments, "/", 2))
    else
      return path
    end
  end

  -- override: fs.combine
  local combine = fs.combine
  function fs.combine(...)
    return "/" .. combine(...)
  end

  -- override: fs.getDir
  local getDir = fs.getDir
  function fs.getDir(p)
    return "/" .. getDir(p)
  end

  -- override: fs.exists
  local exists = fs.exists
  function fs.exists(path)
    checkArg(1, path, "string")
    return exists(resolve(path))
  end

  -- override: fs.list
  local list = fs.list
  function fs.list(path)
    checkArg(1, path, "string")
    path = resolve(path)
    local _, files = pcall(list, path)
    if not _ then return nil, files end
    if path == "/" then
      -- inject /dotos and /user into the root listing
      if not exists("/dotos") then
        files[#files+1] = "dotos"
      end
      if not exists("/user") then
        files[#files+1] = "user"
      end
    end
    return files
  end

  -- override: fs.getSize
  local getSize = fs.getSize
  function fs.getSize(path)
    checkArg(1, path, "string")
    return getSize(resolve(path))
  end

  -- override: fs.isDir
  local isDir = fs.isDir
  function fs.isDir(path)
    checkArg(1, path, "string")
    return isDir(resolve(path))
  end
  
  -- override: fs.makeDir
  local makeDir = fs.makeDir
  function fs.makeDir(path)
    checkArg(1, path, "string")
    return makeDir(resolve(path))
  end
  
  -- override: fs.move
  local move = fs.move
  function fs.move(a, b)
    checkArg(1, a, "string")
    checkArg(2, b, "string")
    return move(resolve(a), resolve(b))
  end
  
  -- override: fs.copy
  local copy = fs.copy
  function fs.copy(a, b)
    checkArg(1, a, "string")
    checkArg(2, b, "string")
    return copy(resolve(a), resolve(b))
  end

  -- override: fs.delete
  local delete = fs.delete
  function fs.delete(path)
    checkArg(1, path, "string")
    return delete(resolve(path))
  end

  -- override: fs.open
  local open = fs.open
  function fs.open(file, mode)
    checkArg(1, file, "string")
    checkArg(2, mode, "string")
    return open(resolve(file), mode or "r")
  end

  -- override: fs.find
  local find = fs.find
  function fs.find(path)
    checkArg(1, path, "string")
    return find(resolve(path))
  end

  -- override: fs.attributes
  local attributes = fs.attributes
  function fs.attributes(path)
    checkArg(1, path, "string")
    return attributes(resolve(path))
  end
end

local io = {}

setmetatable(io, {__index = function(t, k)
  if k == "stdin" then
    return dotos.getio("stdin")
  elseif k == "stdout" then
    return dotos.getio("stdout")
  elseif k == "stderr" then
    return dotos.getio("stderr")
  end
  return nil
end, __metatable = {}})

local function fread(f, ...)
  checkArg(1, f, "table")
  if f.flush then pcall(f.flush, f) end
  local fmt = table.pack(...)
  local results = {}
  local n = 0
  if fmt.n == 0 then fmt[1] = "l" end

  if not f.mode.r then
    return nil, "bad file descriptor"
  end
  
  for i, fmt in ipairs(fmt) do
    if type(fmt) == "string" then fmt = fmt:gsub("%*", "") end
    n = n + 1
    if fmt == "n" then
      error("bad argument to 'read' (format 'n' not supported)")
    elseif fmt == "a" then
      results[n] = f.fd.readAll()
    elseif fmt == "l" or fmt == "L" then
      results[n] = f.fd.readLine(fmt == "L")
    elseif type(fmt) == "number" then
      results[n] = f.fd.read(fmt)
    else
      error("bad argument to 'read' (invalid format '"..fmt.."')")
    end
  end

  return table.unpack(results, 1, n)
end

local function fwrite(f, ...)
  checkArg(1, f, "table")
  
  if not (f.mode.w or f.mode.a) then
    return nil, "bad file descriptor"
  end
  
  local towrite_raw = table.pack(...)
  local towrite = ""
  
  for i, write in ipairs(towrite_raw) do
    checkArg(i+1, write, "string", "number")
    towrite = towrite .. write
  end
  
  f.fd.write(towrite)
  
  return f
end

local function fseek(f, whence, offset)
  checkArg(1, f, "table")
  checkArg(2, whence, "string")
  checkArg(3, offset, "number")
  if not f.fd.seek then
    return nil, "bad file descriptor"
  end
  local ok, err = f.fd.seek(whence, offset)
  if not ok then return nil, err end
  return ok
end

local function fflush(f)
  checkArg(1, f, "table")
  if not (f.mode.w or f.mode.a) then
    return nil, "bad file descriptor"
  end
  f.fd.flush()
  return f
end

local function fclose(f)
  checkArg(1, f, "table")
  f.closed = true
  return f.fd.close()
end

function dotos.mkfile(handle, mode)
  local _mode = {}
  for c in mode:gmatch(".") do
    _mode[c] = true
  end
  return {
    mode = _mode,
    fd = handle,
    read = fread,
    flush = fflush,
    write = fwrite,
    seek = fseek,
    close = fclose,
    lines = io.lines
  }
end

function io.open(file, mode)
  checkArg(1, file, "string")
  checkArg(2, mode, "string", "nil")
  mode = mode or "r"
  local handle, err = fs.open(file, mode)
  if not handle then
    return nil, file .. ": " .. err
  end
  return dotos.mkfile(handle, mode)
end

function io.read(...)
  return io.stdin:read(...)
end

function io.lines(...)
  local args = table.pack(...)
  local f = io.stdin
  if type(args[1]) == "table" then f = table.remove(args, 1) end
  args[1] = args[1] or "l"
  return function()
    return f:read(table.unpack(args, 2, args.n))
  end
end

function io.write(...)
  return io.stdout:write(...)
end

function io.flush(f)
  (f or io.stdout):flush()
end

function io.type(f)
  if not f then return nil end
  if type(f) ~= "table" then return nil end
  if not (f.fd and f.mode and f.read and f.write and f.seek and f.close) then
    return nil end
  return f.closed and "closed file" or "file"
end

function io.close(f)
  f = f or io.stdout
  return f:close()
end

-- make IO field setter
local function mkifs(k, m)
  return function(file)
    checkArg(1, file, "table", "string", "nil")
    if type(file) == "string" then
      file = assert(io.open(file, m))
    end
    if file then
      assert(io.type(file) == "file",
        "bad argument #1 (expected FILE, got table)")
      dotos.setio(k, file)
    end
    return dotos.getio(k)
  end
end

io.input = mkifs("stdin", "r")
io.output = mkifs("stdout", "w")

-- loadfile and dofile here as well
function _G.loadfile(file, mode, env)
  checkArg(1, file, "string")
  checkArg(2, mode, "string", "nil")
  checkArg(3, env, "table", "nil")
  local handle, err = io.open(file, "r")
  if not handle then
    return nil, file .. ": " .. err
  end
  local data = handle:read("a")
  handle:close()
  return load(data, "="..file, "bt", env)
end

function _G.dofile(file, ...)
  checkArg(1, file, "string")
  local func, err = loadfile(file)
  if not func then
    error(err)
  end
  return func(...)
end

return io
?? dotos/libraries/ipc.lua      i-- inter-process communication through message queues --

local dotos = require("dotos")

local lib = {}

local channels = {}
local open = {}

-- basic IPC primitives
local raw = {}
lib.raw = raw

function raw.open(id)
  checkArg(1, id, "number", "string")
  if type(id) == "string" then
    for k, v in pairs(dotos.listthreads()) do
      if v.name == id then id = v.id break end
    end
  end
  if type(id) == "string" or not dotos.running(id) then
    return nil, "IPC target not found"
  end
  local n = #channels + 1
  channels[n] = {to = id, send = {}, recv = {}}
  local pid = dotos.getpid()
  open[pid] = open[pid] or {}
  table.insert(open[pid], n)
  return n
end

function raw.isopen(id)
  checkArg(1, id, "number")
  return not not channels[id]
end

function raw.close(n)
  checkArg(1, n, "number")
  if not channels[n] then
    return nil, "IPC channel not found"
  end
  channels[n] = nil
  return true
end

function raw.send(n, ...)
  checkArg(1, n, "number")
  if not channels[n] then
    return nil, "IPC channel not found"
  end
  local msg = table.pack(n, ...)
  if msg.n == 1 then return end
  table.insert(channels[n].send, msg)
  return true
end

function raw.respond(n, ...)
  checkArg(1, n, "number")
  if not channels[n] then
    return nil, "IPC channel not found"
  end
  local msg = table.pack(...)
  if msg.n == 0 then return end
  table.insert(channels[n].recv, msg)
  return true
end

function raw.receive(n, wait)
  checkArg(1, n, "number", "nil")
  if not n then
    local id = dotos.getpid()
    while true do
      for i, chan in ipairs(channels) do
        if chan.to == id and #chan.send > 0 then
          local t = table.remove(chan.send, 1)
          return table.unpack(t, 1, t.n)
        end
      end
      if wait then
        coroutine.yield()
      else
        break
      end
    end
  else
    if not channels[n] then
      return nil, "IPC channel not found"
    end
    if wait then
      while #channels[n].recv == 0 do coroutine.yield() end
    end
    if #channels[n].recv > 0 then
      local t = table.remove(channels[n].recv, 1)
      return table.unpack(t, 1, t.n)
    end
  end
end

local stream = {}
function stream:sendAsync(...)
  if not raw.isopen(self.id) then self.id = raw.open(self.name) end
  return raw.send(self.id, ...)
end

function stream:receiveAsync()
  if not raw.isopen(self.id) then self.id = raw.open(self.name) end
  return raw.receive(self.id)
end

function stream:receive()
  if not raw.isopen(self.id) then self.id = raw.open(self.name) end
  return raw.receive(self.id, true)
end

function stream:send(...)
  local ok, err = self:sendAsync(...)
  if not ok then return nil, err end
  return self:receive()
end

function stream:close()
  if not raw.isopen(self.id) then
    raw.close(self.id)
  end
end

function lib.connect(name)
  checkArg(1, name, "string")
  local id, err = raw.open(name)
  if not id then return nil, err end
  return setmetatable({name=name,id=id},{__index=stream})
end

local proxy_mt = {
  __index = function(t, k)
    if t.conn[k] then
      return function(_, ...)
        return t.conn[k](t.conn, ...)
      end
    else
      return function(_, ...)
        return t.conn:send(k, ...)
      end
    end
  end
}

function lib.proxy(name)
  checkArg(1, name, "string")
  local conn, err = lib.connect(name)
  if not conn then return nil, err end
  return setmetatable({name=name,conn=conn}, proxy_mt)
end

function lib.listen(api)
  checkArg(1, api, "table")
  while true do
    local request = table.pack(raw.receive())
    if request.n > 0 then
      if not api[request[2]] then
        raw.respond(request[1], nil, "bad api request")
      else
        local req = table.remove(request, 2)
        local result = table.pack(pcall(api[req],
          table.unpack(request, 1, request.n)))
        if result[1] then
          table.remove(result, 1)
        end
        raw.respond(request[1], table.unpack(result, 1, result.n))
      end
    else
      coroutine.yield()
    end
  end
end

-- close IPC streams when threads die
dotos.handle("thread_died", function(id)
  if open[id] then
    for i, handle in ipairs(open[id]) do
      raw.close(handle)
    end
  end
end, true)

return lib
?? dotos/libraries/resources.lua      (-- resource loader --

local path = "/dotos/resources/?.lua;/shared/resources/?.lua"

local lib = {}

function lib.load(name)
  checkArg(1, name, "string")
  local path = package.searchpath(name, path)
  if not path then return nil, "Resource not found" end
  return dofile(path)
end

return lib
?? dotos/libraries/keys.lua      ?-- keyboard related things --

local dotos = require("dotos")

-- automatic keymap detection :)
local kmap = "lwjgl3"
local mcver = tonumber(_HOST:match("%b()"):sub(2,-2):match("1%.(%d+)")) or 0
if _HOST:match("CCEmuX") then
  -- use the 1.16.5 keymap
  kmap = "lwjgl3"
elseif mcver <= 12 or _HOST:match("CraftOS%-PC") then
  -- use the 1.12.2 keymap
  kmap = "lwjgl2"
end

dotos.log("using keymap " .. kmap)

local base = dofile("/dotos/resources/keys/"..kmap..".lua")
local lib = {}

-- reverse-index it!
for k, v in pairs(base) do lib[k] = v; lib[v] = k end
lib["return"] = lib.enter

local pressed = {}
dotos.handle("key", function(_, k)
  pressed[k] = true
end)

dotos.handle("key_up", function(_, k)
  pressed[k] = false
end)

function lib.pressed(k)
  checkArg(1, k, "number")
  return not not pressed[k]
end

function lib.ctrlPressed()
  return pressed[lib.leftControl] or pressed[lib.rightControl]
end

return lib
?? dotos/libraries/argparser.lua      -- basic argument parser --

return function(...)
  local _args = table.pack(...)
  local args = {}
  local opts = {}
  for i, arg in ipairs(_args) do
    if arg:sub(1,1) == "-" then opts[arg:sub(2)] = true
    else args[#args+1] = arg end
  end
  return args, opts
end
?? dotos/libraries/http.lua      #-- HTTP library --

-- native http.request: function(
--  url:string[, post:string[, headers:table[, binarymode:boolean]]])
--    post is the data to POST.  otherwise a GET is sent.
--  OR: function(parameters:table)
--    where parameters = {
--      url = string,     -- the URL
--      body = string,    -- the data to POST/PATCH/PUT
--      headers = table,  -- request headers
--      binary = boolean, -- self explanatory
--      method = string}  -- the HTTP method to use - one of:
--                            - GET
--                            - POST
--                            - HEAD
--                            - OPTIONS
--                            - PUT
--                            - DELETE
--                            - PATCH
--                            - TRACE
--   
-- native http.checkURL: function(url:string)
--    url is a URL to try to reach.  queues a http_check event with the result.
-- native http.websocket(url:string[, headers:table])
--    url is the url to which to open a websocket.  queues a websocket_success
--    event on success, and websocket_failure on failure.
-- native http.addListener(port:number) (CraftOS-PC only)
--    add a listener on the specified port.  when that port receives data,
--    the listener queues a http_request(port:number, request, response).
--    !!the response is not send until response.close() is called!!
-- native http.removeListener(port:number) (CraftOS-PC only)
--    remove the listener from that port

local http = package.loaded.rawhttp

local lib = {}
lib.async = http

function lib.request(url, post, headers, binary, method)
  if type(url) ~= "table" then
    url = {
      url = url,
      body = post,
      headers = headers,
      binary = binary,
      method = method or (post and "POST") or "GET"
    }
  end

  checkArg("url", url.url, "string")
  checkArg("body", url.body, "string", "nil")
  checkArg("headers", url.headers, "table", "nil")
  checkArg("binary", url.binary, "boolean")
  checkArg("method", url.method, "string")

  local ok, err = http.request(url)
  if not ok then
    return nil, err
  end

  while true do
    local sig, a, b, c = coroutine.yield()
    if sig == "http_success" and a == url.url then
      return b
    elseif sig == "http_failure" and a == url.url then
      return nil, b, c
    end
  end
end

function lib.checkURL(url)
  checkArg(1, url, "string")

  local ok, err = http.checkURL(url)
  if not ok then
    return nil, err
  end
  
  local sig, a, b
  repeat
    sig, a, b = coroutine.yield()
  until sig == "http_check" and a == url

  return a, b
end

function lib.websocket(url, headers)
  checkArg(1, url, "string")
  checkArg(2, headers, "string")

  local ok, err = http.websocket(url, headers)
  if not ok then
    return nil, err
  end

  while true do
    local sig, a, b, c = coroutine.yield()
    if sig == "websocket_success" and a == url then
      return b, c
    elseif sig == "websocket_failure" and a == url then
      return nil, b
    end
  end
end

if http.addListener then
  function lib.listen(port, callback)
    checkArg(1, port, "number")
    checkArg(2, callback, "function")
    http.addListener(port)

    while true do
      local sig, a, b, c = coroutine.yield()
      if sig == "stop_listener" and a == port then
        http.removeListener(port)
        break
      elseif sig == "http_request" and  a == port then
        if not callback(b, c) then
          http.removeListener(port)
          break
        end
      end
    end
  end
else
  function lib.listen()
    error("This functionality requires CraftOS-PC", 0)
  end
end

return lib
?? dotos/libraries/vt100.lua      &0-- VT100 layer over top of a surface --

local dotos = require("dotos")
local textutils = require("textutils")
local colors = require("colors")
local keys = require("keys")

assert(colors.loadPalette("vga"))

local vtc = {
  -- standard 8 colors
  colors.black,
  colors.red,
  colors.green,
  colors.yellow,
  colors.blue,
  colors.purple,
  colors.cyan,
  colors.lightGray,
  -- "bright" colors
  colors.darkGray,
  colors.lightRed,
  colors.lightGreen,
  colors.lightYellow,
  colors.lightBlue,
  colors.lightPurple,
  colors.lightCyan,
  colors.white
}

local lib = {}

local vts = {}

local function corral(s)
  while s.cx < 1 do
    s.cy = s.cy - 1
    s.cx = s.cx + s.surface.w
  end

  while s.cx > s.surface.w do
    s.cy = s.cy + 1
    s.cx = s.cx - s.surface.w
  end
  
  while s.cy < 1 do
    s:scroll(-1)
    s.cy = s.cy + 1
  end

  while s.cy >= s.surface.h do
    s:scroll(1)
    s.cy = s.cy - 1
  end
end

function vts:scroll(n)
  if n > 0 then
    for i=n+1, self.surface.h, 1 do
      self.surface.buffer_text[i - n] = self.surface.buffer_text[i]
      self.surface.buffer_fg[i - n] = self.surface.buffer_fg[i]
      self.surface.buffer_bg[i - n] = self.surface.buffer_bg[i]
    end
    self.surface:fill(1, self.surface.h - n, self.surface.w, n, " ")
  elseif n < 0 then
    for i=self.surface.h - n, 1, -1 do
      self.surface.buffer_text[i - n] = self.surface.buffer_text[i]
      self.surface.buffer_fg[i - n] = self.surface.buffer_fg[i]
      self.surface.buffer_bg[i - n] = self.surface.buffer_bg[i]
    end
    self.surface:fill(1, 1, self.surface.w, n, " ")
  end
end

function vts:raw_write(str)
  checkArg(1, str, "string")
  while #str > 0 do
    local nl = str:find("\n") or #str
    local line = str:sub(1, nl)
    str = str:sub(#line + 1)
    local nnl = line:sub(-1) == "\n"
    while #line > 0 do
      local chunk = line:sub(1, self.surface.w - self.cx + 1)
      line = line:sub(#chunk + 1)
      self.surface:set(self.cx, self.cy, chunk)
      self.cx = self.cx + #chunk
      corral(self)
    end
    if nnl and self.cx > 1 then
      self.cx = 1
      self.cy = self.cy + 1
    end
    corral(self)
  end
end

function vts:write(str)
  checkArg(1, str, "string")
  -- hide cursor
  local cc, cf, cb = self.surface:get(self.cx, self.cy, 1)
  self.surface:rawset(self.cx, self.cy, cc, cb, cf)
  while #str > 0 do
    local nesc = str:find("\27")
    local e = (nesc and nesc - 1) or #str
    local chunk = str:sub(1, e)
    str = str:sub(#chunk+1)
    self:raw_write(chunk)
    if nesc then
      local css, paramdata, csc, len
        = str:match("^\27([%[%?])([%d;]*)([%a%[])()")
      str = str:sub(len)
      local args = {}
      for n in paramdata:gmatch("[^;]+") do
        args[#args+1] = tonumber(n)
      end
      if css == "[" then
        -- minimal subset of the standard
        if csc == "[" then
          self:raw_write("^[[")
        elseif csc == "A" then
          args[1] = args[1] or 1
          self.cy = self.cy - args[1]
        elseif csc == "B" then
          args[1] = args[1] or 1
          self.cy = self.cy + args[1]
        elseif csc == "C" then
          args[1] = args[1] or 1
          self.cx = self.cx + args[1]
        elseif csc == "D" then
          args[1] = args[1] or 1
          self.cx = self.cx - args[1]
        elseif csc == "E" then
          args[1] = args[1] or 1
          self.cx = 1
          self.cy = self.cy + args[1]
        elseif csc == "F" then
          args[1] = args[1] or 1
          self.cx = 1
          self.cy = self.cy - args[1]
        elseif csc == "G" then
          args[1] = args[1] or 1
          self.cx = args[1]
        elseif csc == "f" or csc == "H" then
          args[1] = args[1] or 1
          args[2] = args[2] or 1
          self.cy = math.max(1, math.min(self.surface.h-1, args[1]))
          self.cx = math.max(1, math.min(self.surface.w, args[2]))
        elseif csc == "J" then
          local c = args[1] or 0
          if c == 0 then
            self.surface:fill(1, self.cy, self.surface.w,
              self.surface.h - self.cy, " ")
          elseif c == 1 then
            self.surface:fill(1, 1, self.surface.w,
              self.cy, " ")
          elseif c == 2 then
            self.surface:fill(1, 1, self.surface.w, self.surface.h, " ")
          end
        elseif csc == "K" then
          local c = args[1] or 0
          if c == 0 then
            self.surface:fill(self.cx, self.cy, self.surface.w - self.cx, 1,
              " ")
          elseif c == 1 then
            self.surface:fill(1, self.cy, self.cx, 1, " ")
          elseif c == 2 then
            self.surface:fill(1, self.cy, self.surface.w, 1, " ")
          end
        elseif csc == "m" then
          args[1] = args[1] or 0
          for _, c in ipairs(args) do
            if c == 0 then
              self.surface:fg(colors.lightGray)
              self.surface:bg(colors.black)
              self.echo = true
            elseif c == 8 then
              self.echo = false
            elseif c == 28 then
              self.echo = true
            elseif c > 29 and c < 38 then
              self.surface:fg(2^(c-30))--vtc[c - 29])
            elseif c > 39 and c < 48 then
              self.surface:bg(2^(c-40))--vtc[c - 39])
            elseif c > 89 and c < 98 then
              self.surface:fg(2^(c-82))--vtc[c - 81])
            elseif c > 99 and c < 108 then
              self.surface:bg(2^(c-92))--vtc[c - 91])
            elseif c == 39 then
              self.surface:fg(colors.lightGray)
            elseif c == 49 then
              self.surface:bg(colors.black)
            end
          end
        elseif csc == "n" then
          if args[1] == 6 then
            self.ibuf = self.ibuf .. string.format("\27[%d;%dR",
              self.cy, self.cx)
          end
        elseif csc == "S" then
          self:scroll(args[1] or 1)
        elseif csc == "T" then
          self:scroll(-(args[1] or 1))
        end
        corral(self)
      elseif css == "?" then
        if csc == "c" then
          args[1] = args[1] or 0
          for _, n in ipairs(args) do
            if n == 0 then
              self.echo = true
              self.line = true
              self.raw = false
            elseif n == 1 then
              self.echo = true
            elseif n == 2 then
              self.line = true
            elseif n == 3 then
              self.raw = true
            elseif n == 11 then
              self.echo = false
            elseif n == 12 then
              self.line = false
            elseif n == 13 then
              self.raw = false
            end
          end
        end
      end
    else
      break
    end
  end
  -- show cursor
  local ccc, ccf, ccb = self.surface:get(self.cx, self.cy, 1)
  self.surface:rawset(self.cx, self.cy, ccc, ccb, ccf)
end

function vts:readc()
  while #self.ibuf == 0 do coroutine.yield() end
  local byte = self.ibuf:sub(1,1)
  self.ibuf = self.ibuf:sub(2)
  return byte
end

function vts:readline(knl)
  checkArg(1, knl, "boolean", "nil")
  while not self.ibuf:match("\n") do coroutine.yield() end
  local n = self.ibuf:find("\n")
  local ln = self.ibuf:sub(1, n)
  self.ibuf = self.ibuf:sub(#ln + 1)
  if not knl then ln = ln:sub(1, -2) end
  return ln
end

function vts:read(n)
  checkArg(1, n, "number")
  local ret = ""
  if self.line and not self.raw then
    while not self.ibuf:match("\n") do coroutine.yield() end
  end
  repeat
    local c = self:readc()
    ret = ret .. c
  until #ret == n or ((not self.raw) and c == "\4")
  if ret:sub(-1) == "\4" and not self.raw then
    ret = ret:sub(1, -2)
    if #ret == 0 then return nil end
  end
  return ret
end

function vts:close()
  dotos.drop(self.specialhandler)
  dotos.drop(self.charhandler)
  dotos.drop(self.resizehandler)
end

function lib.new(surf)
  checkArg(1, surf, "table")
  surf:fg(colors.lightGray)
  surf:bg(colors.black)
  surf:fill(1, 1, surf.w, surf.h, " ")
  local new
  new = setmetatable({
    cx = 1, cy = 1, ibuf = "", echo = true,
    surface = surf, specialhandler = dotos.handle("key", function(_, k)
      if k == keys.backspace then
        if new.raw then
          new.ibuf = new.ibuf .. "\8"
        else
          if #new.ibuf > 0 and new.ibuf:sub(-1) ~= "\n" then
            new.ibuf = new.ibuf:sub(1, -2)
            if new.echo then new:write("\27[D \27[D") end
          end
        end
      elseif k == keys.enter then
        if new.raw then
          new.ibuf = new.ibuf .. "\r"
        else
          if new.echo then new:write("\n") end
          new.ibuf = new.ibuf .. "\n"
        end
      elseif k == keys.up then
        if new.echo and not new.raw then new:write("\27[[A") end
        new.ibuf = new.ibuf .. "\27[A"
      elseif k == keys.down then
        if new.echo and not new.raw then new:write("\27[[B") end
        new.ibuf = new.ibuf .. "\27[B"
      elseif k == keys.left then
        if new.echo and not new.raw then new:write("\27[[D") end
        new.ibuf = new.ibuf .. "\27[D"
      elseif k == keys.right then
        if new.echo and not new.raw then new:write("\27[[C") end
        new.ibuf = new.ibuf .. "\27[C"
      elseif keys.ctrlPressed() and #keys[k] == 1 then
        local byte = string.byte(keys[k])
        if byte > 96 and byte < 123 then
          new.ibuf = new.ibuf .. string.char(byte - 96)
        end
      end
    end), charhandler = dotos.handle("char", function(_, c)
      if new.echo then new:write(c) end
      new.ibuf = new.ibuf .. c
    end), resizehandler = dotos.handle("term_resize", function()
      if new.term then
        local nw, nh = new.term.getSize()
        new.surface:resize(nw, nh + 1)
        new.cy = math.min(new.cy, nh)
      end
    end)
  }, {__index = vts, __metatable = {}})
  return new
end

return lib
?? dotos/libraries/dottk.lua      L.-- .TK: the DoT OS UI toolkit v2 --

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
?? dotos/libraries/package.lua      ?-- package library --

local package = {}

package.config = "/\n;\n?\n!\n-"
package.cpath = ""
package.path = "/dotos/libraries/?.lua;/user/libraries/?.lua;/shared/libaries/?.lua"
package.loaded = {
  _G = _G,
  io = io,
  os = os,
  math = math,
  utf8 = utf8,
  table = table,
  debug = debug,
  bit32 = bit32,
  string = string,
  package = package,
  coroutine = coroutine,
}
package.preload = {}

package.searchers = {
  -- check package.preload
  function(mod)
    if package.preload[mod] then
      return package.preload[mod]
    else
      return nil, "no field package.preload['" .. mod .. "']"
    end
  end,
  -- check for lua library
  function(mod)
    local ok, err = package.searchpath(mod, package.path, ".", "/")
    if not ok then
      return nil, err
    end
    local func, aerr = loadfile(ok)
    if not func then
      return nil, aerr
    end
    return func()
  end
}

local fs = fs
local term = term
local function remove(k)
  package.loaded[k] = _G[k]
  _G[k] = nil
end
package.loaded.rawhttp = http
_G.http = nil
for _, api in ipairs({"fs", "term","peripheral", "periphemu", "mounter",
    "config", "redstone", "rs", "dotos"}) do
  remove(api)
end

function package.searchpath(name, path, sep, rep)
  checkArg(1, name, "string")
  checkArg(2, path, "string")
  checkArg(3, sep, "string", "nil")
  checkArg(4, rep, "string", "nil")

  sep = "%" .. (sep or ".")
  rep = rep or "/"

  name = name:gsub(sep, rep)
  local serr = ""

  for search in path:gmatch("[^;]+") do
    search = search:gsub("%?", name)
    if fs.exists(search) then
      return search
    else
      if #serr > 0 then
        serr = serr .. "\n  "
      end
      serr = serr .. "no file '" .. search .. "'"
    end
  end

  return nil, serr
end

function _G.require(mod)
  checkArg(1, mod, "string")

  if package.loaded[mod] then
    return package.loaded[mod]
  end

  local serr = "module '" .. mod .. "' not found:"
  for _, searcher in ipairs(package.searchers) do
    local result, err = searcher(mod)
    if result then
      package.loaded[mod] = result
      return result
    else
      serr = serr .. "\n  " .. err
    end
  end

  error(serr, 2)
end

return package
?? dotos/binaries/tle.lua      [X-- TLE - The Lua Editor.  Licensed under the DSLv2. --

-- basic terminal interface library --

local vt = {}

function vt.set_cursor(x, y)
  io.write(string.format("\27[%d;%dH", y, x))
end

function vt.get_cursor()
  io.write("\27[6n")
  local resp = ""
  repeat
    local c = io.read(1)
    resp = resp .. c
  until c == "R"
  print(resp:sub(2))
  local y, x = resp:match("\27%[(%d+);(%d+)R")
  return tonumber(x), tonumber(y)
end

function vt.get_term_size()
  local cx, cy = vt.get_cursor()
  vt.set_cursor(9999, 9999)
  local w, h = vt.get_cursor()
  vt.set_cursor(cx, cy)
  return w, h
end

-- keyboard interface with standard VT100 terminals --

local kbd = {}

local patterns = {
  ["1;7."] = {ctrl = true, alt = true},
  ["1;5."] = {ctrl = true},
  ["1;3."] = {alt = true}
}

local substitutions = {
  A = "up",
  B = "down",
  C = "right",
  D = "left",
  ["5"] = "pgUp",
  ["6"] = "pgDown",
}

-- this is a neat party trick.  works for all alphabetical characters.
local function get_char(ascii)
  return string.char(96 + ascii:byte())
end

function kbd.get_key()
--  os.execute("stty raw -echo")
  local data = io.read(1)
  local key, flags
  if data == "\27" then
    local intermediate = io.read(1)
    if intermediate == "[" then
      data = ""
      repeat
        local c = io.read(1)
        data = data .. c
        if c:match("[a-zA-Z]") then
          key = c
        end
      until c:match("[a-zA-Z]")
      flags = {}
      for pat, keys in pairs(patterns) do
        if data:match(pat) then
          flags = keys
        end
      end
      key = substitutions[key] or "unknown"
    else
      key = io.read(1)
      flags = {alt = true}
    end
  elseif data:byte() > 31 and data:byte() < 127 then
    key = data
  elseif data:byte() == 127 then
    key = "backspace"
  else
    key = get_char(data)
    flags = {ctrl = true}
  end
  --os.execute("stty sane")
  return key, flags
end

local rc
-- VLERC parsing
-- yes, this is for TLE.  yes, it's using VLERC.  yes, this is intentional.

rc = {syntax=true,cachelastline=true}

do
  local function split(line)
    local words = {}
    for word in line:gmatch("[^ ]+") do
      words[#words + 1] = word
    end
    return words
  end

  local function pop(t) return table.remove(t, 1) end

  local fields = {
    bi = "builtin",
    bn = "blank",
    ct = "constant",
    cm = "comment",
    is = "insert",
    kw = "keyword",
    kc = "keychar",
    st = "string",
  }
  local colors = {
    black = 30,
    gray = 90,
    lightGray = 37,
    red = 91,
    green = 92,
    yellow = 93,
    blue = 94,
    magenta = 95,
    cyan = 96,
    white = 97
  }
  
  local function parse(line)
    local words = split(line)
    if #words < 1 then return end
    local c = pop(words)
    -- color keyword 32
    -- co kw green
    if c == "color" or c == "co" and #words >= 2 then
      local field = pop(words)
      field = fields[field] or field
      local color = pop(words)
      if colors[color] then
        color = colors[color]
      else
        color = tonumber(color)
      end
      if not color then return end
      rc[field] = color
    elseif c == "cachelastline" then
      local arg = pop(words)
      arg = (arg == "yes") or (arg == "true") or (arg == "on")
      rc.cachelastline = arg
    elseif c == "syntax" then
      local arg = pop(words)
      rc.syntax = (arg == "yes") or (arg == "true") or (arg == "on")
    end
  end

  local home = os.getenv("HOME")
  local handle = io.open(home .. "/.vlerc", "r")
  if handle then
    for line in handle:lines() do
      parse(line)
    end
    handle:close()
  end
end
-- rewritten syntax highlighting engine

local syntax = {}

do
  local function esc(n)
    return string.format("\27[%dm", n)
  end
  
  local colors = {
    keyword = esc(rc.keyword or 91),
    builtin = esc(rc.builtin or 92),
    constant = esc(rc.constant or 95),
    string = esc(rc.string or 93),
    comment = esc(rc.comment or 90),
    keychar = esc(rc.keychar or 94),
    operator = esc(rc.operator or rc.keychar or 94)
  }
  
  local function split(l)
    local w = {}
    for wd in l:gmatch("[^ ]+") do
      w[#w+1]=wd
    end
    return w
  end
  
  local function parse_line(self, line)
    local words = split(line)
    local cmd = words[1]
    if not cmd then
      return
    elseif cmd == "keychars" then
      for i=2, #words, 1 do
        self.keychars = self.keychars .. words[i]
      end
    elseif cmd == "comment" then
      self.comment = words[2] or "#"
    elseif cmd == "keywords" then
      for i=2, #words, 1 do
        self.keywords[words[i]] = true
      end
    elseif cmd == "const" then
      for i=2, #words, 1 do
        self.constants[words[i]] = true
      end
    elseif cmd == "constpat" then
      for i=2, #words, 1 do
        self.constpat[#self.constpat+1] = words[i]
      end
    elseif cmd == "builtin" then
      for i=2, #words, 1 do
        self.builtins[words[i]] = true
      end
    elseif cmd == "operator" then
      for i=2, #words, 1 do
        self.operators[words[i]] = true
      end
    elseif cmd == "strings" then
      if words[2] == "on" then
        self.strings = "\"'"
      elseif words[2] == "off" then
        self.strings = false
      else
        self.strings = self.strings .. (words[2] or "")
      end
    end
  end
  
  -- splits on keychars and spaces
  -- groups together blocks of identical keychars
  local function asplit(self, line)
    local words = {}
    local cword = ""
    local opchars = ""
    --for k in pairs(self.operators) do
    --  opchars = opchars .. k
    --end
    --opchars = "["..opchars:gsub("[%[%]%(%)%.%+%%%$%-%?%^%*]","%%%1").."]"
    for char in line:gmatch(".") do
      local last = cword:sub(-1) or ""
      if #self.keychars > 2 and char:match(self.keychars) then
        if last == char then -- repeated keychar
          cword = cword .. char
        else -- time to split!
          if #cword > 0 then words[#words+1] = cword end
          cword = char
        end
      elseif #self.keychars > 2 and last:match(self.keychars) then
        -- also time to split
        if #cword > 0 then words[#words+1] = cword end
        if char == " " then
          words[#words+1]=char
          cword = ""
        else
          cword = char
        end
      -- not the cleanest solution, but it'll do
      elseif #last > 0 and self.operators[last .. char] then
        if #cword > 0 then words[#words + 1] = cword:sub(1,-2) end
        words[#words+1] = last..char
        cword = ""
      elseif self.strings and char:match(self.strings) then
        if #cword > 0 then words[#words+1] = cword end
        words[#words+1] = char
        cword = ""
      elseif char == " " then
        if #cword > 0 then words[#words+1] = cword end
        words[#words+1] = " "
        cword = ""
      else
        cword = cword .. char
      end
    end
    
    if #cword > 0 then
      words[#words+1] = cword
    end
    
    return words
  end
  
  local function isconst(self, word)
    if self.constants[word] then return true end
    for i=1, #self.constpat, 1 do
      if word:match(self.constpat[i]) then
        return true
      end
    end
    return false
  end
  
  local function isop(self, word)
    return self.operators[word]
  end
  
  local function iskeychar(self, word)
    return #self.keychars > 2 and not not word:match(self.keychars)
  end
  
  local function highlight(self, line)
    local ret = ""
    local strings, comment = self.strings, self.comment
    local words = asplit(self, line)
    local in_str, in_cmt
    for i, word in ipairs(words) do
      --io.stderr:write(word, "\n")
      if strings and word:match(strings) and not in_str and not in_cmt then
        in_str = word:sub(1,1)
        ret = ret .. colors.string .. word
      elseif in_str then
        ret = ret .. word
        if word == in_str then
          ret = ret .. "\27[39m"
          in_str = false
        end
      elseif word:sub(1,#comment) == comment then
        in_cmt = true
        ret = ret .. colors.comment .. word
      elseif in_cmt then
        ret = ret .. word
      else
        local esc = (self.keywords[word] and colors.keyword) or
                    (self.builtins[word] and colors.builtin) or
                    (isconst(self, word) and colors.constant) or
                    (isop(self, word) and colors.operator) or
                    (iskeychar(self, word) and colors.keychar) or
                    ""
        ret = string.format("%s%s%s%s", ret, esc, word,
          (esc~=""and"\27[39m"or""))
      end
    end
    ret = ret .. "\27[39m"
    return ret
  end
  
  function syntax.load(file)
    local new = {
      keywords = {},
      operators = {},
      constants = {},
      constpat = {},
      builtins = {},
      keychars = "",
      comment = "#",
      strings = "\"'",
      highlighter = highlight
    }
    local handle = assert(io.open(file, "r"))
    for line in handle:lines() do
      parse_line(new, line)
    end
    if new.strings then
      new.strings = string.format("[%s]", new.strings)
    end
    new.keychars = string.format("[%s]", (new.keychars:gsub(
      "[%[%]%(%)%.%+%%%$%-%?%^%*]", "%%%1")))
    return function(line)
      return new:highlighter(line)
    end
  end
end


local args = {...}

local cbuf = 1
local w, h = 1, 1
local buffers = {}

local function get_abs_path(file)
  local pwd = os.getenv("PWD")
  if file:sub(1,1) == "/" or not pwd then return file end
  return string.format("%s/%s", pwd, file):gsub("[\\/]+", "/")
end

local function read_file(file)
  local handle, err = io.open(file, "r")
  if not handle then
    return ""
  end
  local data = handle:read("a")
  handle:close()
  return data
end

local function write_file(file, data)
  local handle, err = io.open(file, "w")
  if not handle then return end
  handle:write(data)
  handle:close()
end

local function get_last_pos(file)
  local abs = get_abs_path(file)
  local pdata = read_file(os.getenv("HOME") .. "/.vle_positions")
  local pat = abs:gsub("[%[%]%(%)%^%$%%%+%*%*]", "%%%1") .. ":(%d+)\n"
  if pdata:match(pat) then
    local n = tonumber(pdata:match(pat))
    return n or 1
  end
  return 1
end

local function save_last_pos(file, n)
  local abs = get_abs_path(file)
  local escaped = abs:gsub("[%[%]%(%)%^%$%%%+%*%*]", "%%%1")
  local pat = "(" .. escaped .. "):(%d+)\n"
  local vp_path = os.getenv("HOME") .. "/.vle_positions"
  local data = read_file(vp_path)
  if data:match(pat) then
    data = data:gsub(pat, string.format("%%1:%d\n", n))
  else
    data = data .. string.format("%s:%d\n", abs, n)
  end
  write_file(vp_path, data)
end

local commands -- forward declaration so commands and load_file can access this
local function load_file(file)
  local n = #buffers + 1
  buffers[n] = {name=file, cline = 1, cpos = 0, scroll = 0, lines = {}, cache = {}}
  local handle = io.open(file, "r")
  cbuf = n
  if not handle then
    buffers[n].lines[1] = ""
    return
  end
  for line in handle:lines() do
    buffers[n].lines[#buffers[n].lines + 1] =
                                     (line:gsub("[\r\n]", ""):gsub("\t", "  "))
  end
  handle:close()
  --[[buffers[n].cline = math.min(#buffers[n].lines,
    get_last_pos(get_abs_path(file)))
  buffers[n].scroll = math.min(1, buffers[n].cline - h)]]
  if commands and commands.t then commands.t() end
end

if args[1] == "--help" then
  print("usage: tle [FILE]")
  os.exit()
elseif args[1] then
  for i=1, #args, 1 do
    load_file(args[i])
  end
else
  buffers[1] = {name="<new>", cline = 1, cpos = 0, scroll = 1, lines = {""}, cache = {}}
end

local function truncate_name(n, bn)
  if #n > 16 then
    n = "..." .. (n:sub(-13))
  end
  if buffers[bn].unsaved then n = n .. "*" end
  return n
end

-- TODO: may not draw correctly on small terminals or with long buffer names
local function draw_open_buffers()
  vt.set_cursor(1, 1)
  local draw = "\27[2K\27[46m"
  local dr = ""
  for i=1, #buffers, 1 do
    dr = dr .. truncate_name(buffers[i].name, i) .. "   "
    draw = draw .. "\27[36m \27["..(i == cbuf and "107" or "46")..";30m " .. truncate_name(buffers[i].name, i) .. " \27[46m"
  end
  local diff = string.rep(" ", w - #dr)
  draw = draw .. "\27[46m" .. diff .. "\27[39;49m"
  if #dr:gsub("\27%[[%d.]+m", "") > w then
    draw = draw:sub(1, w)
  end
  io.write(draw, "\27[39;49m")--, "\n\27[G\27[2K\27[36m", string.rep("-", w))
end

local function draw_line(line_num, line_text)
  local write
  if line_text then
    line_text = line_text:gsub("\t", " ")
    if #line_text > (w - 4) then
      line_text = line_text:sub(1, w - 5)
    end
    if buffers[cbuf].highlighter then
      line_text = buffers[cbuf].highlighter(line_text)
    end
    write = string.format("\27[2K\27[36m%4d\27[37m %s", line_num,
                                   line_text)
  else
    write = "\27[2K\27[96m~\27[37m"
  end
  io.write(write)
end

-- dynamically getting dimensions makes the experience slightly nicer for the
-- 2%, at the cost of a rather significant performance drop on slower
-- terminals.  hence, I have removed it.
--
-- to re-enable it, just move the below line inside the draw_buffer() function.
-- you may want to un-comment it.
-- w, h = vt.get_term_size()
local function draw_buffer()
  io.write("\27[39;49m")
  if os.getenv("TERM") == "cynosure" then
    io.write("\27?14c")
  end
  draw_open_buffers()
  local buffer = buffers[cbuf]
  local top_line = buffer.scroll
  for i=1, h - 1, 1 do
    local line = top_line + i - 1
    if (not buffer.cache[line]) or
        (buffer.lines[line] and buffer.lines[line] ~= buffer.cache[line]) then
      vt.set_cursor(1, i + 1)
      draw_line(line, buffer.lines[line])
      buffer.cache[line] = buffer.lines[line] or "~"
    end
  end
  if os.getenv("TERM") == "cynosure" then
    io.write("\27?4c")
  end
end

local function update_cursor()
  local buf = buffers[cbuf]
  local mw = w - 5
  local cx = (#buf.lines[buf.cline] - buf.cpos) + 6
  local cy = buf.cline - buf.scroll + 2
  if cx > mw then
    vt.set_cursor(1, cy)
    draw_line(buf.cline, (buf.lines[buf.cline]:sub(cx - mw + 1, cx)))
    cx = mw
  end
  vt.set_cursor(cx, cy)
end

local arrows -- these forward declarations will kill me someday
local function insert_character(char)
  local buf = buffers[cbuf]
  buf.unsaved = true
  if char == "\n" then
    local text = ""
    local old_cpos = buf.cpos
    if buf.cline > 1 then -- attempt to get indentation of previous line
      local prev = buf.lines[buf.cline]
      local indent = #prev - #(prev:gsub("^[%s]+", ""))
      text = (" "):rep(indent)
    end
    if buf.cpos > 0 then
      text = text .. buf.lines[buf.cline]:sub(-buf.cpos)
      buf.lines[buf.cline] = buf.lines[buf.cline]:sub(1,
                                          #buf.lines[buf.cline] - buf.cpos)
    end
    table.insert(buf.lines, buf.cline + 1, text)
    arrows.down()
    buf.cpos = old_cpos
    return
  end
  local ln = buf.lines[buf.cline]
  if char == "\8" then
    buf.cache[buf.cline] = nil
    buf.cache[buf.cline - 1] = nil
    buf.cache[buf.cline + 1] = nil
    buf.cache[#buf.lines] = nil
    if buf.cpos < #ln then
      buf.lines[buf.cline] = ln:sub(0, #ln - buf.cpos - 1)
                                                  .. ln:sub(#ln - buf.cpos + 1)
    elseif ln == "" then
      if buf.cline > 1 then
        table.remove(buf.lines, buf.cline)
        arrows.up()
        buf.cpos = 0
      end
    elseif buf.cline > 1 then
      local line = table.remove(buf.lines, buf.cline)
      local old_cpos = buf.cpos
      arrows.up()
      buf.cpos = old_cpos
      buf.lines[buf.cline] = buf.lines[buf.cline] .. line
    end
  else
    buf.lines[buf.cline] = ln:sub(0, #ln - buf.cpos) .. char
                                                  .. ln:sub(#ln - buf.cpos + 1)
  end
end

local function trim_cpos()
  if buffers[cbuf].cpos > #buffers[cbuf].lines[buffers[cbuf].cline] then
    buffers[cbuf].cpos = #buffers[cbuf].lines[buffers[cbuf].cline]
  end
  if buffers[cbuf].cpos < 0 then
    buffers[cbuf].cpos = 0
  end
end

local function try_get_highlighter()
  local ext = buffers[cbuf].name:match("%.(.-)$")
  if not ext then
    return
  end
  local try = "/dotos/resources/tle/"..ext..".vle"
  local also_try = "/user/tle/"..ext..".vle"
  local ok, ret = pcall(syntax.load, also_try)
  if ok then
    return ret
  else
    ok, ret = pcall(syntax.load, try)
    if ok then
      return ret
    else
      ok, ret = pcall(syntax.load, "syntax/"..ext..".vle")
      if ok then
        io.stderr:write("OKAY")
        return ret
      end
    end
  end
  return nil
end

arrows = {
  up = function()
    local buf = buffers[cbuf]
    if buf.cline > 1 then
      local dfe = #(buf.lines[buf.cline] or "") - buf.cpos
      buf.cline = buf.cline - 1
      if buf.cline < buf.scroll and buf.scroll > 0 then
        buf.scroll = buf.scroll - 1
        io.write("\27[T") -- scroll up
        buf.cache[buf.cline] = nil
      end
      buf.cpos = #buf.lines[buf.cline] - dfe
    end
    trim_cpos()
  end,
  down = function()
    local buf = buffers[cbuf]
    if buf.cline < #buf.lines then
      local dfe = #(buf.lines[buf.cline] or "") - buf.cpos
      buf.cline = buf.cline + 1
      if buf.cline > buf.scroll + h - 3 then
        buf.scroll = buf.scroll + 1
        io.write("\27[S") -- scroll down, with some VT100 magic for efficiency
        buf.cache[buf.cline] = nil
      end
      buf.cpos = #buf.lines[buf.cline] - dfe
    end
    trim_cpos()
  end,
  left = function()
    local buf = buffers[cbuf]
    if buf.cpos < #buf.lines[buf.cline] then
      buf.cpos = buf.cpos + 1
    elseif buf.cline > 1 then
      arrows.up()
      buf.cpos = 0
    end
  end,
  right = function()
    local buf = buffers[cbuf]
    if buf.cpos > 0 then
      buf.cpos = buf.cpos - 1
    elseif buf.cline < #buf.lines then
      arrows.down()
      buf.cpos = #buf.lines[buf.cline]
    end
  end,
  -- not strictly an arrow but w/e
  backspace = function()
    insert_character("\8")
  end
}

-- TODO: clean up this function
local function prompt(text)
  -- box is max(#text, 18)x3
  local box_w = math.max(#text, 18)
  local box_x, box_y = math.floor(w/2) - math.floor(box_w/2),
    math.floor(h/2) - 1
  vt.set_cursor(box_x, box_y)
  io.write("\27[46m", string.rep(" ", box_w))
  vt.set_cursor(box_x, box_y)
  io.write("\27[30;46m", text)
  local inbuf = ""
  local function redraw()
    vt.set_cursor(box_x, box_y + 1)
    io.write("\27[46m", string.rep(" ", box_w))
    vt.set_cursor(box_x + 1, box_y + 1)
    io.write("\27[36;40m", inbuf:sub(-(box_w - 2)), string.rep(" ",
                                                          (box_w - 2) - #inbuf))
    vt.set_cursor(box_x, box_y + 2)
    io.write("\27[46m", string.rep(" ", box_w))
    vt.set_cursor(box_x + 1 + math.min(box_w - 2, #inbuf), box_y + 1)
  end
  repeat
    redraw()
    local c, f = kbd.get_key()
    f = f or {}
    if c == "backspace" or (f.ctrl and c == "h") then
      inbuf = inbuf:sub(1, -2)
    elseif not (f.ctrl or f.alt) then
      inbuf = inbuf .. c
    end
  until (c == "m" and (f or {}).ctrl)
  io.write("\27[39;49m")
  buffers[cbuf].cache = {}
  return inbuf
end

local prev_search
commands = {
  b = function()
    if cbuf < #buffers then
      cbuf = cbuf + 1
      buffers[cbuf].cache = {}
    end
  end,
  v = function()
    if cbuf > 1 then
      cbuf = cbuf - 1
      buffers[cbuf].cache = {}
    end
  end,
  f = function()
    local search_pattern = prompt("Search pattern:")
    if #search_pattern == 0 then search_pattern = prev_search end
    prev_search = search_pattern
    for i = buffers[cbuf].cline + 1, #buffers[cbuf].lines, 1 do
      if buffers[cbuf].lines[i]:match(search_pattern) then
        commands.g(i)
        return
      end
    end
    for i = 1, #buffers[cbuf].lines, 1 do
      if buffers[cbuf].lines[i]:match(search_pattern) then
        commands.g(i)
        return
      end
    end
  end,
  g = function(i)
    i = i or tonumber(prompt("Goto line:"))
    i = math.min(i, #buffers[cbuf].lines)
    buffers[cbuf].cline = i
    buffers[cbuf].scroll = i - math.min(i, math.floor(h / 2))
  end,
  k = function()
    local del = prompt("# of lines to delete:")
    del = tonumber(del)
    if del and del > 0 then
      for i=1, del, 1 do
        local ln = buffers[cbuf].cline
        if ln > #buffers[cbuf].lines then return end
        table.remove(buffers[cbuf].lines, ln)
      end
      buffers[cbuf].cpos = 0
      buffers[cbuf].unsaved = true
      if buffers[cbuf].cline > #buffers[cbuf].lines then
        buffers[cbuf].cline = #buffers[cbuf].lines
      end
    end
  end,
  r = function()
    local search_pattern = prompt("Search pattern:")
    local replace_pattern = prompt("Replace with?")
    for i = 1, #buffers[cbuf].lines, 1 do
      buffers[cbuf].lines[i] = buffers[cbuf].lines[i]:gsub(search_pattern,
                                                                replace_pattern)
    end
  end,
  t = function()
    buffers[cbuf].highlighter = try_get_highlighter()
    buffers[cbuf].cache = {}
  end,
  h = function()
    insert_character("\8")
  end,
  m = function() -- this is how we insert a newline - ^M == "\n"
    insert_character("\n")
  end,
  n = function()
    local file_to_open = prompt("Enter file path:")
    load_file(file_to_open)
  end,
  s = function()
    local ok, err = io.open(buffers[cbuf].name, "w")
    if not ok then
      prompt(err)
      return
    end
    for i=1, #buffers[cbuf].lines, 1 do
      ok:write(buffers[cbuf].lines[i], "\n")
    end
    ok:close()
    save_last_pos(buffers[cbuf].name, buffers[cbuf].cline)
    buffers[cbuf].unsaved = false
  end,
  w = function()
    -- the user may have unsaved work, prompt
    local unsaved
    for i=1, #buffers, 1 do
      if buffers[i].unsaved then
        unsaved = true
       break
      end
    end
    if unsaved then
      local really = prompt("Delete unsaved work? [y/N] ")
      if really ~= "y" then
        return
      end
    end
    table.remove(buffers, cbuf)
    cbuf = math.min(cbuf, #buffers)
    if #buffers == 0 then
      commands.q()
    end
    buffers[cbuf].cache = {}
  end,
  q = function()
    if #buffers > 0 then -- the user may have unsaved work, prompt
      local unsaved
      for i=1, #buffers, 1 do
        if buffers[i].unsaved then
          unsaved = true
          break
        end
      end
      if unsaved then
        local really = prompt("Delete unsaved work? [y/N] ")
        if really ~= "y" then
          return
        end
      end
    end
    io.write("\27[2J\27[1;1H\27[m")
    if os.getenv("TERM") == "paragon" then
      io.write("\27(r\27(L")
    elseif os.getenv("TERM") == "cynosure" then
      io.write("\27?13;2c")
    else
      os.execute("stty sane")
    end
    os.exit()
  end
}

for i=1, #buffers, 1 do
  cbuf = i
  buffers[cbuf].highlighter = try_get_highlighter()
end
io.write("\27[2J")
if os.getenv("TERM") == "paragon" then
  io.write("\27(R\27(l\27[8m")
elseif os.getenv("TERM") == "cynosure" then
  io.write("\27?3;12c\27[8m")
else
  os.execute("stty raw -echo")
end
w, h = vt.get_term_size()

while true do
  draw_buffer()
  update_cursor()
  local key, flags = kbd.get_key()
  flags = flags or {}
  if flags.ctrl then
    if commands[key] then
      commands[key]()
    end
  elseif flags.alt then
  elseif arrows[key] then
    arrows[key]()
  elseif #key == 1 then
    insert_character(key)
  end
end
?? dotos/binaries/lua.lua      ?-- lua REPL --

local args = table.pack(...)
local opts = {}

local readline = require("readline")

-- prevent some pollution of _G
local prog_env = {}
for k, v in pairs(_G) do prog_env[k] = v end

local exfile, exargs = nil, {}
local ignext = false
for i=1, #args, 1 do
  if ignext then
    ignext = false
  else
    if args[i] == "-e" and not exfile then
      opts.e = args[i + 1]
      if not opts.e then
        io.stderr:write("lua: '-e' needs argument\n")
        opts.help = true
        break
      end
      ignext = true
    elseif args[i] == "-l" and not exfile then
      local arg = args[i + 1]
      if not arg then
        io.stderr:write("lua: '-l' needs argument\n")
        opts.help = true
        break
      end
      prog_env[arg] = require(arg)
      ignext = true
    elseif (args[i] == "-h" or args[i] == "--help") and not exfile then
      opts.help = true
      break
    elseif args[i] == "-i" and not exfile then
      opts.i = true
    elseif args[i]:match("%-.+") and not exfile then
      io.stderr:write("lua: unrecognized option '", args[i], "'\n")
      opts.help = true
      break
    elseif exfile then
      exargs[#exargs + 1] = args[i]
    else
      exfile = args[i]
    end
  end
end

opts.i = #args == 0

if opts.help then
  io.stderr:write([=[
usage: lua [options] [script [args ...]]
Available options are:
  -e stat  execute string 'stat'
  -i       enter interactive mode after executing 'script'
  -l name  require library 'name' into global 'name'
  -v       show version information

ULOS Coreutils (c) 2021 Ocawesome101 under the
DSLv2.
]=])
  os.exit(1)
end

if opts.e then
  local ok, err = load(opts.e, "=(command line)", "bt", prog_env)
  if not ok then
    io.stderr:write("lua: ", err, "\n")
    os.exit(1)
  else
    local result = table.pack(xpcall(ok, debug.traceback))
    if not result[1] and result[2] then
      io.stderr:write("lua: ", result[2], "\n")
      os.exit(1)
    elseif result[1] then
      print(table.unpack(result, 2, result.n))
    end
  end
end

opts.v = opts.v or opts.i
if opts.v then
  if _VERSION == "Lua 5.1" then
    io.write(_VERSION, "  Copyright (C) 1994-2012 Lua.org, PUC-Rio\n")
  elseif _VERSION == "Lua 5.2" then
    io.write(_VERSION, "  Copyright (C) 1994-2015 Lua.org, PUC-Rio\n")
  elseif _VERSION == "Lua 5.3" then
    io.write(_VERSION, "  Copyright (C) 1994-2020 Lua.org, PUC-Rio\n")
  elseif _VERSION == "Lua 5.4" then
    io.write(_VERSION, "  Copyright (C) 1994-2021 Lua.org, PUC-Rio\n")
  end
end

if exfile then
  local ok, err = loadfile(exfile, "t", prog_env)
  if not ok then
    io.stderr:write("lua: ", err, "\n")
    os.exit(1)
  end
  local result = table.pack(xpcall(ok, debug.traceback,
    table.unpack(exargs, 1, #exargs)))
  if not result[1] and result[2] then
    io.stderr:write("lua: ", result[2], "\n")
    os.exit(1)
  end
end

if opts.i or (not opts.e and not exfile) then
  local hist = {}
  local rlopts = {history = hist}
  while true do
    io.write("> ")
    local eval = readline(rlopts)
    hist[#hist+1] = eval
    local ok, err = load("return "..eval, "=stdin", "bt", prog_env)
    if not ok then
      ok, err = load(eval, "=stdin", "bt", prog_env)
    end
    if not ok then
      io.stderr:write(err, "\n")
    else
      local result = table.pack(xpcall(ok, debug.traceback))
      if not result[1] and result[2] then
        io.stderr:write(result[2], "\n")
      elseif result[1] then
        print(table.unpack(result, 2, result.n))
      end
    end
  end
end
?? dotos/binaries/dotsh.lua      \-- .SH: a simple shell --

local dotos = require("dotos")
local dotsh = require("dotsh")
local readline = require("readline")

local handle = io.open("/user/motd.txt", "r")
if not handle then
  handle = io.open("/dotos/motd.txt", "r")
end
if handle then
  print(dotsh.expand(handle:read("a")))
  handle:close()
end

os.setenv("SHLVL", (os.getenv("SHLVL") or 0) + 1)

local function drawprompt()
  io.write(string.format("\27[93;49m%s\27[39m: \27[94m%s\27[93m$\27[39m ",
    dotos.getuser(), dotos.getpwd()))
end

local hist = {}
local rlopts = {history = hist, exit = os.exit}
while true do
  drawprompt()
  local input = readline(rlopts)

  if #input > 0 then
    table.insert(hist, input)
    input = dotsh.expand(input)
    local ok, err = pcall(dotsh.execute, input)
    if not ok then
      print(string.format("\27[91m%s\27[39m", err))
    end
  end
end
?? dotos/binaries/help.lua      wlocal look = table.concat({...}, " ")
local search = "/dotos/help/?;/shared/help/?"
local aliases = {
  dotos = main,
  [""] = "main"
}
look = aliases[look or "main"] or look or "main"
look = look:gsub(" ", "_")
local path = package.searchpath(look, search)
if not path then
  error("no available help entry", 0)
end
assert(loadfile("/dotos/binaries/pager.lua"))("-E", path)
?? dotos/binaries/pager.lua      ?local args, opts = require("argparser")(...)
local dotsh = require("dotsh")
if opts.help then
  io.stderr:write([[
usage: pager [options] [file ...]
Page through the specified file(s).
Options:
  -E,--expand   call dotsh.expand on the text
                (DO NOT TRUST A TEXT FILE WITHOUT
                FIRST CHECKING ITS CONTENTS, THIS
                IS A POTENTIALLY DESTRUCIVE
                ACTION!)
  --help        show this help text

Copyright (c) 2022 DoT Software under the MIT license.
]])
  return
end
if not args[1] then return end

local w, h = require("termio").getTermSize()

local printed = 0
for _, file in ipairs(args) do
  local name = require("fs").getName(file)
  local handle = assert(io.open(file, "r"))
  local data = handle:read("a")
  handle:close()
  if opts.E then
    data = dotsh.expand(data)
  end
  local lines = require("textutils").lines(data)
  for i=1, #lines, 1 do
    print(lines[i])
    printed = printed + math.max(1,
      math.ceil(#lines[i]:gsub("\27%[[%d;]*%a", "") / w))
    if printed >= h - 3 then
      io.write("\27[33m-- " .. name .. " - press Enter for more --\27[39m")
      io.read()
      io.write("\27[A\27[2K")
      printed = 0
    end
  end
end
?? dotos/binaries/mkdir.lua       flocal file = ...
local ok, err = require("fs").makeDir(file)
if not ok and err then error(err, 0) end
?? dotos/binaries/set.lua      ?-- set --

local args, opts = require("argparser")(...)
local settings = require("settings")

local file = "/.dotos.cfg"

if opts.f then
  file = table.remove(args, 1)
end

if #args == 0 or #args > 2 then
  error("usage: set [-f file] KEY [VALUE]", 0)
elseif #args == 1 then
  print(args[1] .. " = " .. tostring(settings.get(file, args[1])))
else
  settings.set(file, args[1], args[2])
  print(args[1] .. " = " .. tostring(settings.get(file, args[1])))
end
?? dotos/binaries/list.lua      P-- list --

local args, opts = require("argparser")(...)
local textutils = require("textutils")
local dotos = require("dotos")
local fs = require("fs")

local path = args[1] or dotos.getpwd()
if not fs.isDir(path) then
  error("list: "..path..": not a directory", 0)
end
if path:sub(1,1) ~= "/" then path = fs.combine(dotos.getpwd(), path) end
local files = fs.list(path)
table.sort(files)

local w = require("termio").getTermSize()
local out = ""
local x = 0
local len = 0
for i=1, #files, 1 do
  if #files[i] > len then len = #files[i] end
end
for i, file in ipairs(files) do
  if file:sub(1,1) ~= "." or opts.a then
    local full = fs.combine(path, file)
    if not opts.nocolor then
      if fs.isDir(full) then
        out = out .. "\27[34m"
      elseif full:sub(-4) == ".lua" then
        out = out .. "\27[32m"
      else
        out = out .. "\27[97m"
      end
    end
    file = textutils.padRight(file, len)
    if (x + #file + 3 > w or opts.one) and x > 0 then
      x = 0
      out = out .. "\n"
    end
    x = x + #file + 2
    out = out .. file .. "  "
  end
end

print(out)

os.exit()
?? dotos/binaries/cat.lua       ?local args = {...}

for i=1, #args, 1 do
  local handle, err = io.open(args[i], "r")
  if not handle then error(err, 0) end
  print(handle:read("a"))
  handle:close()
end
os.exit()
?? dotos/binaries/delete.lua       ?local args = {...}
local ok, err = require("fs").delete(args[1])
if not ok and err then error(args[1] .. ": " .. err, 0) end
os.exit()
?? dotos/binaries/users.lua       ?local args = {...}

if #args == 0 then
  for name in pairs(require("settings").load("/.users.cfg")) do print(name) end
  return
end
require("fs").makeDir("/users/"..args[1])
require("settings").set("/.users.cfg", args[1], args[2] or "thing")

os.exit()
?? dotos/binaries/logs.lua      ?-- view logs --

local logs = require("dotos").getlogs()
local tutils = require("textutils")
local w, h = require("term").getSize()
local printed = 0
for i=1, #logs, 1 do
  for _, line in ipairs(tutils.wordwrap(logs[i], w)) do
    print((line:gsub("^%[([%d:]+)%]", "\27[92m[\27[35m%1\27[92m]\27[39m")))
    printed = printed + 1
    if printed > h - 2 then
      io.write("[ press Return for more ]")
      io.read()
      io.write("\27[A\27[2K")
      printed = 0
    end
  end
end
?? dotos/binaries/ps.lua       ?print("TID  NAME")
for i, thread in ipairs(require("dotos").listthreads()) do
  print(string.format("%4d %s", thread.id, thread.name))
end
?? dotos/binaries/iface.lua      -- iface: switch interfaces on-the-fly --

local ipc = require("ipc")
local args, opts = require("argparser")(...)

if #args == 0 or opts.help then
  io.stderr:write([[
usage: iface <interface>
Connect to ifaced and switch the system interface
without requiring a reboot.

Copyright (c) 2022 DoT Software under the MIT
license.
]])
  os.exit()
end

local iface = args[1]

local conn = ipc.proxy("ifaced")
local ok, err = conn:start(iface)
if not ok then
  io.stderr:write("\27[91m"..err.."\n")
end
conn.conn:close()

?? dotos/binaries/login.lua      )local dotos = require("dotos")
local users = require("users")
local rl = require("readline")
while true do
  print("\27[2J\27[H\n\27[33m ## \27[93m.OS Login\27[33m ##\27[39m\n")
  io.write("Username: ")
  local name = rl()
  io.write("Password: \27[8m")
  local pw = io.read("l")
  io.write("\27[m\n\n")
  local pid, err = users.runas(name, pw,
    assert(loadfile("/dotos/binaries/dotsh.lua")), ".SH")
  if not pid then
    print("\27[91m" .. err .. "\27[39m")
    os.sleep(3)
  else
    repeat coroutine.yield() until not dotos.running(err)
  end
end
?? dotos/binaries/kill.lua       ,require("dotos").kill(tonumber((...)) or 0)
?? dotos/binaries/power.lua       ?local args, opts = require("argparser")(...)

if opts.s then
  os.shutdown()
elseif opts.r then
  os.reboot()
else
  error("usage: power [-s|-r]", 0)
end
?? dotos/help/main      ?{ORANGE} == {YELLOW}.OS Help {ORANGE}=={WHITE}

This is the .OS help database.  In it you will find documentation for most things relating to .OS and its usage.

You can gain a more complete picture of the available help pages by looking in {YELLOW}/dotos/help{WHITE}.  The {BLUE}help{WHITE} utility will also search {YELLOW}/shared/help{WHITE}.

Some pages you may wish to look at:
  {YELLOW}dotsh {ORANGE}-{YELLOW} dotui {ORANGE}-{YELLOW} line editing{WHITE}

{ORANGE} == {YELLOW}.OS Help {ORANGE}=={WHITE}
?? dotos/help/line_editing       {ORANGE}=={YELLOW} Line Editing {ORANGE}=={WHITE}

{YELLOW}.SH{WHITE} uses a line editing scheme very similar to GNU Readline.  It supports the following shortcuts:

  {ORANGE}-{BLUE} Ctrl-A{WHITE}  Cursor to beginning of line
  {ORANGE}-{BLUE} Ctrl-E{WHITE}  Cursor to end of line

Arrow keys move the cursor left and right.  Pressing {BLUE}Enter{WHITE} sends the string of text to be processed by the application (usually {YELLOW}.SH{WHITE} or {YELLOW}Lua{WHITE}).

 {ORANGE}=={YELLOW} Line Editing {ORANGE}=={WHITE}
?? dotos/help/dotsh      0{ORANGE} =={YELLOW} dotsh {ORANGE}=={WHITE}

{YELLOW}dotsh{WHITE} (stylized: {YELLOW}.SH{WHITE}) is the default command interpreter and interface for {YELLOW}.OS{WHITE}.  It sports a unique curly-bracket-based shell syntax which described later in this help text.

See also the page on {YELLOW}line editing{WHITE}.

{ORANGE}--{YELLOW} Weird Syntax {ORANGE}--{WHITE}
{YELLOW}.SH{WHITE}'s special syntax is based around balanced sets of curly braces ({RED}{}{WHITE}).  If inside these is a valid argument, then its corresponding action will be performed and it will be replaced with the result.

The following special keywords may be present:
  {ORANGE}-{RED} RED{WHITE}     insert a vt100 escape for red color
  {ORANGE}-{RED} WHITE{WHITE}   insert a vt100 escape for white color
  {ORANGE}-{RED} BLUE{WHITE}    insert a vt100 escape for blue color
  {ORANGE}-{RED} YELLOW{WHITE}  insert a vt100 escape for yellow color
  {ORANGE}-{RED} ORANGE{WHITE}  insert a vt100 escape for orange color
  {ORANGE}-{RED} GREEN{WHITE}   insert a vt100 escape for green color

The following special syntax is accepted:
  {ORANGE}.{YELLOW}foo{WHITE}
    Execute command {YELLOW}foo{WHITE} and substitute its output.  Equivalent to Bash's {RED}$(foo){WHITE}

  {ORANGE}.>{GREEN}file {YELLOW}foo{WHITE}
    Execute command {YELLOW}foo{WHITE} and redirect its output into {GREEN}file{WHITE}.

  {ORANGE}.+{GREEN}file {YELLOW}foo{WHITE}
    Like {RED}.>{WHITE}, but also return the command's output like {RED}.{WHITE}.

  {ORANGE}${YELLOW}bar{WHITE}
    Get the value of the environment variable {YELLOW}bar{WHITE}.

  {ORANGE}$@{YELLOW}bar{ORANGE}={YELLOW}baz{WHITE}
    Set the environment variable {YELLOW}bar{WHITE} to {YELLOW}baz{WHITE}.

  {ORANGE}$+{YELLOW}bar{ORANGE}={YELLOW}baz{WHITE}
    Like {RED}$@{WHITE}, but also returns {YELLOW}baz{WHITE}.

  {ORANGE}$!{YELLOW}bar{WHITE}
    Unset the environment variable {YELLOW}bar{WHITE}.

  {ORANGE}$?{WHITE}
    Return a concatenated list of all the available environment variables, one per line;  currently:

{$?}

{ORANGE} == {YELLOW}dotsh{ORANGE} =={WHITE}
?? dotos/help/interfaces      B{ORANGE} == {YELLOW}Interfaces{ORANGE} == {WHITE}

One of {YELLOW}.OS{WHITE}'s distinguishing features in the ComputerCraft OS space is its concept of {ORANGE}interfaces{WHITE}.  This allows users to use whatever paradigm with which they feel most comfortable, and to switch between them with a reboot.

You can change the interface into which the system boots by running

  {BLUE}set interface {ORANGE}interface{WHITE}

For example:

  {BLUE}set interface {ORANGE}dotsh{WHITE}

change the system interface to {YELLOW}dotsh{WHITE}.

Which interface is displayed onscreen is managed by the System Interface Manager, {YELLOW}ifaced{ORANGE}.  This exports a simple interface over {YELLOW}.OS{WHITE}'s IPC mechanism to allow starting and stopping of interfaces at runtime, as well as switching between them, much more seamlessly than with the old system that required a reboot.  It can be controlled with the {YELLOW}iface{WHITE} command.

See also:
  {YELLOW}dotsh{ORANGE} - {YELLOW}dotui{ORANGE} - {YELLOW}dotwm{ORANGE} - {YELLOW}ipc{WHITE}

{ORANGE} == {YELLOW}Interfaces{ORANGE} == {WHITE}
?? dotos/help/keymaps      8{ORANGE} == {YELLOW}Keymaps{ORANGE} == {WHITE}

One of the design goals of {YELLOW}.OS{WHITE} is to run on versions of CC: Tweaked for Minecraft 1.12 and older, as well as 1.13 and newer, without the user having to touch anything and also while not depending at all on CraftOS.  This is accomplished through {ORANGE}keymaps{WHITE}.

There are currently two supported keymaps, {RED}lwjgl2{WHITE} and {RED}lwjgl3{WHITE}.  These can be found under {YELLOW}/dotos/resources/keys{WHITE}.

On first boot, the system keymap is configured by the startup script {YELLOW}/dotos/startup/01_init_settings.lua{YELLOW}.  This will automatically select the correct keymap based on the value of the global variable {RED}_HOST{WHITE}.  Currently it will select {RED}lwjgl2{WHITE} if this variable indicates Minecraft 1.12.2 or lower, or if it indicates CraftOS-PC.  Otherwise it will select the {RED}lwjgl3{WHITE} keymap.  If for some reason the script guessed wrong, you may change the keymap through the {RED}keyboardLayout{WHITE} system setting.

{ORANGE} == {YELLOW}Keymaps{ORANGE} == {WHITE}
?? dotos/help/dotui      ?{ORANGE} == {YELLOW}dotui{ORANGE} == {WHITE}

{YELLOW}dotui{WHITE} (stylized {YELLOW}.UI{WHITE}) is the first iteration of {YELLOW}.OS{WHITE}'s graphical user interface stack.  Its user interface toolkit, while functional, requires a rather significant amount of boilerplate code and is rather inflexible.  {YELLOW}.WM{WHITE}, a better window manager, and {YELLOW}.TK{WHITE}, a replacement GUI toolkit, are intended to solve both of these problems in a reasonably sane manner.

To change the system interface to {YELLOW}.ui{WHITE}, run {BLUE}set interface dotui{WHITE} in the shell and reboot.

See also:
  {YELLOW}interfaces{ORANGE} - {YELLOW}dotwm{ORANGE} - {YELLOW}dottk{WHITE}

{ORANGE} == {YELLOW}dotui{ORANGE} == {WHITE}
?? dotos/appdefs/taskmgr.desc       ]{
  name = "Task Manager",
  procname = ".taskmanager",
  exec = "/dotos/apps/taskmgr.lua"
}
?? dotos/appdefs/syslog.desc       V{
  name = "System Logs",
  procname = ".syslog",
  exec = "/dotos/apps/syslog.lua"
}
?? dotos/appdefs/demo.desc       P{
  name = "UI Demo",
  procname = ".uidemo",
  exec = "/dotos/apps/demo.lua"
}
?? dotos/appdefs/settings.desc       d{
  name = "System Settings",
  procname = ".systemsettings",
  exec = "/dotos/apps/settings.lua"
}
?? dotos/appdefs/filemangler.desc       ^{
  name = "File Mangler",
  procname = ".fmangler",
  exec = "/dotos/apps/filemangler.lua"
}
?? dotos/interfaces/dotsh/main.lua      ?-- .SH: text-based shell for power-users --

local dotos = require("dotos")
local term = require("term")
local sigtypes = require("sigtypes")

local surface = require("surface").new(term.getSize())
surface:resize(surface.w, surface.h + 1)

local stream = require("iostream").wrap(surface)
stream.fd.vt.term = term
stream.tty = true
io.input(stream)
io.output(stream)
dotos.setio("stderr", stream)

local id = dotos.spawn(function()
  dofile("/dotos/binaries/login.lua")
end, ".clilogin")

-- the IO stream has its own "cursor", so disable the default CC one
term.setCursorBlink(false)
--dotos.logio = stream
while dotos.running(id) do
  surface:draw(1,1)
  coroutine.yield()
end
dotos.logio = nil
dotos.log("shutting down")
os.sleep(3)
os.shutdown()
??  dotos/interfaces/dotwm/dotwm.lua      -- The DoT OS Window Manager --

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
?? "dotos/interfaces/dotwm/wmlogin.lua      ?-- login --

local dotos = require("dotos")
local users = require("users")
local tk = require("dottk")
local wm = require("dotwm")
local colors = require("colors")

local root 
repeat
  root = wm.connect()
  if not root then coroutine.yield() end
until root

local logged_in = false

local uname, pass = "", ""
local win = tk.Window:new({
  w = 12, h = 7,
  root = root,
  position = "centered"
})


local pid 
local status = ""
local status_col = colors.white
local status_bg

local layout = tk.Grid:new({
  w = 12, h = 7,
  rows = 7, cols = 1,
  window = win,
}):addChild(1, 1, tk.Text:new({
  window = win,
  text = ".OS Login",
  position = "center"
})):addChild(6, 1, tk.Text:new({
  window = win,
  text = function(self)
    self.textcol = status_col
    self.bgcol = status_bg
    return status
  end,
  --position = "center",
})):addChild(2, 1, tk.Text:new({
  window = win,
  text = "Username",
  position = "center"
})):addChild(3, 1, tk.InputBox:new({
  window = win,
  position = "center",
  width = 0.8,
  onchar = function(self)
    uname = self.buffer
  end
})):addChild(4, 1, tk.Text:new({
  window = win,
  text = "Password",
  position = "center",
})):addChild(5, 1, tk.InputBox:new({
  window = win,
  position = "center",
  width = 0.8,
  mask = "\7",
  onchar = function(self)
    pass = self.buffer
  end
})):addChild(7, 1, tk.Grid:new({
  window = win,
  w = 10, h = 1,
  rows = 1, cols = 2,
}):addChild(1, 2, tk.Button:new({
  window = win,
  text = "Log In",
  callback = function(self)
    if users.auth(uname, pass) then
      local _
      root.removeWindow(win.windowid)
      _, pid = users.runas(uname, pass, function()
        local ok, err = loadfile("/dotos/interfaces/dotwm/desktop.lua", "DE")
        if not ok then
          status = "Failed"
          status_col = colors.red
          status_bg = colors.white
        else
          logged_in = true
          ok()
        end
      end, ".desktop")
    else
      status_col = colors.red
      status_bg = colors.white
      status = "Bad Login"
    end
  end
})))

while true do
  win:addChild(1, 1, layout)
  while not logged_in do
    coroutine.yield()
  end
  while dotos.running(pid) do
    coroutine.yield()
  end
  logged_in = false
end
?? "dotos/interfaces/dotwm/desktop.lua      	?-- .OS Desktop Interface --

local dotos = require("dotos")
local fs = require("fs")
local tk = require("dottk")
local wm = require("dotwm")

local root
repeat
  root = wm.connect()
  coroutine.yield()
until root

local height = 6
local rf, uf = fs.list("/dotos/appdefs"), fs.list("/shared/appdefs")
if rf then height = height + #rf end
if uf then height = height + #uf end

local window = tk.Window:new({
  root = root,
  w = 15,
  h = height,
})

local reboot = false

local grid = tk.Grid:new({
  window = window,
  rows = height - 1,
  columns = 1
}):addChild(1, 1, tk.Text:new{
  window = window,
  text = " "..("\x8c"):rep(13).." ",
}):addChild(2, 1, tk.Button:new{
  window = window,
  text = "Settings",
  position = "center",
}):addChild(height - 3, 1, tk.Text:new{
  window = window,
  text = " "..("\x8c"):rep(13).." ",
}):addChild(height - 2, 1, tk.Checkbox:new{
  window = window,
  text = "Restart?",
  callback = function(self) reboot = self.selected end
}):addChild(height - 1, 1, tk.Button:new{
  window = window,
  text = "Shut Down",
  position = "center",
  callback = function() if reboot then os.reboot() else os.shutdown() end end,
})

local function readfile(f)
  local handle = io.open(f, "r")
  local data = handle:read("a")
  handle:close()
  return data
end

if rf then
  for i, f in ipairs(rf) do
    local ok, err = load("return"..readfile("/dotos/appdefs/"..f), "="..f,
      "t", {})
    if ok then
      local def = ok()
      grid:addChild(i + 2, 1, tk.Button:new{
        window = window,
        text = def.name,
        position = "center",
        callback = function()
          dotos.spawn(function()
            dofile(def.exec)
          end, def.procname or def.name)
        end,
      })
    else
      grid:addChild(i + 2, 1, tk.Text:new{
        window = window,
        text = "load failed",
        position = "center"
      })
    end
  end
end

window:addChild(1, 1, tk.TitleBar:new{
  window = window,
  text = "Menu"
}):addChild(1, 2, grid)

local ok, err = pcall(tk.Dialog.new, tk.Dialog, {
  root = root,
  text = "Error!"
})

if not ok and err then
  local win = tk.Window:new({root=root,w=#err,h=2})
  win:addChild(1,1,tk.TitleBar:new{window=win})
  win:addChild(1,2,tk.Text:new({window=win,text=err}))
end

while true do
  local sig, id, reason = coroutine.yield()
  if window.closed then
    window.closed = false
    root.addWindow(window)
  end
  if sig == "thread_died" then
    tk.Dialog:new {
      root = root,
      text = reason
    }
  end
end
?? dotos/interfaces/dotwm/main.lua      x-- start the .WM Login Manager --

local dotos = require("dotos")

local wmpid, loginpid
local function restart_wm()
  wmpid = dotos.spawn(function()
    dofile("/dotos/interfaces/dotwm/dotwm.lua")
  end, ".wm")
end

local loginfile = "/dotos/interfaces/dotwm/desktop.lua"
--local loginfile = "/dotos/interfaces/dotwm/wmlogin.lua"

local function restart_login()
  loginpid = dotos.spawn(function()
    dofile(loginfile)
  end, "login")
end

restart_wm()
restart_login()

while true do
  coroutine.yield()
  if not dotos.running(wmpid) then
    restart_wm()
  end
  if not dotos.running(loginpid) then
    restart_login()
  end
end
?? #dotos/interfaces/dotui/shutdown.lua      -- shutdown prompt --

local dotos = require("dotos")
local dotui = require("dotui")

local window, base = dotui.util.basicWindow(3, 3, 24, 10, "Shutdown")

local page = dotui.UIPage:new {
  x = 2, y = 2, w = base.w - 2, h = base.h - 1,
}
base:addChild(page)

page.text = "Choose an action to perform:"
page.wrap = true

local items = {
  "Shut Down",
  "Restart"
}

local itemFunctions = {
  os.shutdown,
  os.reboot
}

local selector = dotui.Selector:new {
  x = 2, y = 4, w = page.w, h = #items,
  items = items,
  exclusive = true
}

selector.selected[1] = true

page:addChild(selector)

page:addChild( dotui.Clickable:new {
  x = page.w - 7, y = page.h - 1, w = 7, h = 1,
  text = "Confirm",
  callback = function()
    for i, func in ipairs(itemFunctions) do
      if selector.selected[i] then
        func()
      end
    end
  end
} )

dotui.util.genericWindowLoop(window)

dotos.exit()
?? "dotos/interfaces/dotui/desktop.lua      -- .OS Desktop --

local dotos = require("dotos")
local dotui = require("dotui")
local colors = require("colors")
local types = require("sigtypes")

local window = dotui.window.create(1, 1, 1, 1)
window.keepInBackground = true

local base = dotui.UIPage:new {
  x = 1, y = 1, w = window.w, h = window.h,
  fg = colors.gray, bg = colors.lightBlue, surface = window.buffer
}

base:addChild(dotui.Label:new {
  x = 1, y = 0, w = #os.version(), h = 1,
  fg = colors.gray, bg = colors.lightBlue, text = os.version()
})

local menubar = dotui.UIPage:new {
  x = 1, y = 1, w = window.w, h = 1,
  fg = colors.lightBlue, bg = colors.gray
}

local menupid = 0
local menubtn = dotui.Clickable:new {
  x = 1,
  y = 1,
  w = 6, h = 1,
  callback = function()
    if not dotos.running(menupid) then
      menupid = dotui.util.loadApp(".menu", "/dotos/interfaces/dotui/menu.lua")
        or 0
    else
      dotos.kill(menupid)
    end
  end,
  text = " Menu "
}

base:addChild(menubar)
menubar:addChild(menubtn)

local surface = window.buffer
while true do
  surface:fill(1, 1, surface.w, surface.h, " ", colors.lightBlue,
    colors.lightBlue)
  surface:fill(1, 1, surface.w, 1, " ", colors.lightBlue, colors.gray)
  base:draw()
  local sig = window:receiveSignal()
  if sig[1] == "mouse_click" then
    local element = base:find(sig[3], sig[4])
    if element then
      element:callback()
    else
      dotos.kill(menupid)
    end
  elseif sig[1] == "thread_died" then
    dotui.util.prompt(sig[3], {"OK",
      title = "Thread " .. sig[2] .. " Died"})
  end
end
?? dotos/interfaces/dotui/menu.lua      U-- .UI menu --

local dotos = require("dotos")
local dotui = require("dotui")
local fs = require("fs")

local window = dotui.window.create(1, 2, 16, 4)
local base = dotui.Menu:new {
  x = 1, y = 1, w = window.w, h = window.h,
}
window.noDropShadow = true
window:addPage("main", base)

local desktopFilePaths = {
  "/dotos/appdefs/",
  "/user/appdefs/"
}

base:addItem("Shut Down", function()
  dotui.util.loadApp(".shutdown", "/dotos/interfaces/dotui/shutdown.lua")
  window.delete = true
end)

base:addSpacer()

window.keepOnTop = true

window.h = 2
for i, path in ipairs(desktopFilePaths) do
  if fs.exists(path) then
    local files = fs.list(path)
    window.h = window.h + #files
    for i, file in ipairs(files) do
      local handle = io.open(path..file, "r")
      local data = handle:read("a")
      handle:close()
      local func, err = load("return " .. data, "="..file, "t", {})
      if not func then
        dotos.spawn(function()
          dotui.util.prompt(err, {"OK", title = "App Load Error"})
          dotos.exit()
        end, ".appDescErr")
      else
        local desc = func()
        base:addItem(desc.name, function()
          window.delete = true
          dotui.util.loadApp(desc.procname, desc.exec)
        end)
      end
    end
  end
end
base.h = window.h
window.buffer:resize(window.w, window.h)

while not window.delete do
  window:draw()
  local sig = window:receiveSignal()
  if sig[1] == "unfocus" then
    window.delete = true
  elseif sig[1] == "mouse_click" then
    local element = window:find(sig[3], sig[4])
    if element then element:callback() end
  end
end

dotos.exit()
?? dotos/interfaces/dotui/main.lua      ?-- main .UI file --
-- this is the low-level-ish window manager

local dotos = require("dotos")
local term = require("term")
local surf = require("surface")
local colors = require("colors")
local sigtypes = require("sigtypes")
local cfg = require("settings").load("/.dotos.cfg")

dotos.log("[.ui] The DoT UI is now starting")

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
?? dotos/resources/keys/lwjgl2.lua      9-- keymap for minecraft 1.12.2 and older

return {
  nil,
  "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
  "zero", "minus", "equals", "backspace", "tab", "q", "w", "e", "r", "t", "y",
  "u", "i", "o", "p", "leftBracket", "rightBracket", "enter", "leftControl",
  "a", "s", "d", "f", "g", "h", "j", "k", "l", "semicolon", "apostrophe",
  "grave", "leftShift", "backslash", "z", "x", "c", "v", "b", "n", "m",
  "comma", "period", "slash", "rightShift", "multiply", "leftAlt", "space",
  "capsLock", "f1", "f2", "f3", "f4", "f5", "f6", "f7", "f8", "f9", "f10",
  "numLock", "scrollLock", "numpad7", "numpad8", "numpad9", "numpadSubtract",
  "numpad4", "numpad5", "numpad6", "numpadAdd", "numpad1", "numpad2", "numpad3",
  "numpad0", "numpadDot", nil, nil, nil, "f11", "f12", nil, nil, nil, nil, nil,
  nil, nil, nil, nil, nil, nil, "f13", "f14", "f15", nil, nil, nil, nil, nil,
  nil, nil, nil, nil, "kana", nil, nil, nil, nil, nil, nil, nil, nil, "convert",
  nil, "noconvert", nil, "yen", nil, nil, nil, nil, nil, nil, nil, nil, nil,
  nil, nil, nil, nil, nil, nil, "numpadEquals", nil, nil, "circumflex", "at",
  "colon", "underscore", "kanji", "stop", "ax", nil, nil, nil, nil, nil,
  "numpadEnter", "rightControl", nil, nil, nil, nil, nil, nil, nil, nil, nil,
  nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, "numpadComma",
  nil, "numpadDivide", nil, nil, "rightAlt", nil, nil, nil, nil, nil, nil,
  nil, nil, nil, nil, nil, nil, "pause", nil, "home", "up", "pageUp", nil,
  "left", nil, "right", nil, "end", "down", "pageDown", "insert", "delete"
}
?? dotos/resources/keys/lwjgl3.lua      m-- keymap for 1.16.5+ 

return {
  [32] = "space",
  [39] = "apostrophe",
  [44] = "comma",
  [45] = "minus",
  [46] = "period",
  [47] = "slash",
  [48] = "zero",
  [49] = "one",
  [50] = "two",
  [51] = "three",
  [52] = "four",
  [53] = "five",
  [54] = "six",
  [55] = "seven",
  [56] = "eight",
  [57] = "nine",
  [59] = "semicolon",
  [61] = "equals",
  [65] = "a",
  [66] = "b",
  [67] = "c",
  [68] = "d",
  [69] = "e",
  [70] = "f",
  [71] = "g",
  [72] = "h",
  [73] = "i",
  [74] = "j",
  [75] = "k",
  [76] = "l",
  [77] = "m",
  [78] = "n",
  [79] = "o",
  [80] = "p",
  [81] = "q",
  [82] = "r",
  [83] = "s",
  [84] = "t",
  [85] = "u",
  [86] = "v",
  [87] = "w",
  [88] = "x",
  [89] = "y",
  [90] = "z",
  [91] = "leftBracket",
  [92] = "backslash",
  [93] = "rightBracket",
  [96] = "grave",
  [257] = "enter",
  [258] = "tab",
  [259] = "backspace",
  [260] = "insert",
  [261] = "delete",
  [262] = "right",
  [263] = "left",
  [264] = "down",
  [265] = "up",
  [266] = "pageUp",
  [267] = "pageDown",
  [268] = "home",
  [269] = "end",
  [280] = "capsLock",
  [281] = "scrollLock",
  [282] = "numLock",
  [283] = "printScreen",
  [284] = "pause",
  [290] = "f1",
  [291] = "f2",
  [292] = "f3",
  [293] = "f4",
  [294] = "f5",
  [295] = "f6",
  [296] = "f7",
  [297] = "f8",
  [298] = "f9",
  [299] = "f10",
  [300] = "f11",
  [301] = "f12",
  [302] = "f13",
  [303] = "f14",
  [304] = "f15",
  [305] = "f16",
  [306] = "f17",
  [307] = "f18",
  [308] = "f19",
  [309] = "f20",
  [310] = "f21",
  [311] = "f22",
  [312] = "f23",
  [313] = "f24",
  [314] = "f25",
  [320] = "numpad0",
  [321] = "numpad1",
  [322] = "numpad2",
  [323] = "numpad3",
  [324] = "numpad4",
  [325] = "numpad5",
  [326] = "numpad6",
  [327] = "numpad7",
  [328] = "numpad8",
  [329] = "numpad9",
  [330] = "numpadDot",
  [331] = "numpadDivide",
  [332] = "numpadMultiply",
  [333] = "numpadSubtract",
  [334] = "numpadAdd",
  [335] = "numpadEnter",
  [336] = "numpadEqual",
  [340] = "leftShift",
  [341] = "leftControl",
  [342] = "leftAlt",
  [343] = "leftSuper",
  [344] = "rightShift",
  [345] = "rightControl",
  [346] = "rightAlt",
  [348] = "menu",
}
?? $dotos/resources/palettes/craftos.lua      ?-- default ComputerCraft color palette --

return {
  0xf0f0f0,
  0xf2b233,
  0xe57fd8,
  0x99b2f2,
  0xd2d26c,
  0x7fcc19.
  0xf2b2cc,
  0x4c4c4c,
  0x999999,
  0x4c99b2,
  0xb266e5,
  0x3366cc,
  0x7f664c,
  0x57a64e,
  0xcc4c4c,
  0x111111
}, {
  "white",
  "orange",
  "magenta",
  "lightBlue",
  "yellow",
  "lime",
  "pink",
  "gray",
  "lightGray",
  "cyan",
  "purple",
  "blue",
  "brown",
  "green",
  "red",
  "black"
}
??  dotos/resources/palettes/vga.lua      ?-- the 16 (almost-)standard VGA colors --

return {
  0x000000,
  0xaa0000,
  0x00aa00,
  0xaa5500,
  0x0055aa,
  0xaa00aa,
  0x00aaaa,
  0xaaaaaa,
  0x555555,
  0xff5555,
  0x55ff55,
  0xffff55,
  0x5555ff,
  0xff55ff,
  0x55ffff,
  0xffffff
}, {
  "black", "red", "green", "yellow", "blue", "purple", "cyan",
  "lightGray", "darkGray", "lightRed", "lightGreen", "lightYellow",
  "lightBlue", "lightPurple", "lightCyan", "white"
}
?? $dotos/resources/palettes/default.lua      ?-- default color palette --

return {
  0x000000,
  0x606060,
  0xb0b0b0,
  0xaa0000,
  0xff0000,
  0x00aa00,
  0x00ff00,
  0x0080ff,
  0x66b6ff,
  0x6600aa,
  0x9000ff,
  0x6030f0,
  0xffff00,
  0xff8000,
  0x40ffff,
  0xffffff
}, {
  "black",
  "gray",   "lightGray",
  "red",    "lightRed",
  "green",  "lightGreen",
  "blue",   "lightBlue",
  "purple", "magenta",
  "brown",  "yellow",
  "orange", "cyan",
  "white"
}
?? dotos/resources/tle/lua.vle      S# VLE highlighting V2: Electric Boogaloo
# this is probably the most feature-complete syntax file of the ones i've
# written, mostly because Lua is the language I know best.

comment --
const true false nil
keychars []{}(),:;+-/=~<>&|^%#*
operator + - / // = ~= >> << > < & * | ^ % .. #
keywords const close local while for repeat until do if in else elseif and or not then end
keywords function return goto break
constpat ^[%d%.]+$
constpat ^0x[0-9a-fA-F%.]+$
builtin tonumber dofile xpcall pcall require string setmetatable package warn _G
builtin ipairs arg load assert utf8 debug getmetatable print error next rawlen
builtin coroutine select io math pairs _VERSION rawequal table type rawget
builtin loadfile os tostring collectgarbage rawset
# all builtins from Lua 5.4
builtin string.match string.find string.packsize string.gmatch string.dump
builtin string.format string.len string.sub string.pack string.char string.byte
builtin string.upper string.reverse string.gsub string.unpack string.rep 
builtin string.lower package.config package.loaded package.cpath
builtin package.searchers package.path package.preload package.searchpath
builtin package.loadlib _G.tonumber _G.dofile _G.xpcall _G.pcall _G.require
builtin _G.string _G.setmetatable _G.package _G.warn _G._G _G.ipairs _G.arg
builtin _G.load _G.assert _G.utf8 _G.debug _G.getmetatable _G.print _G.error
builtin _G.next _G.rawlen _G.coroutine _G.select _G.io _G.math _G.pairs
builtin _G._VERSION _G.rawequal _G.table _G.type _G.rawget _G.loadfile _G.os
builtin _G.tostring _G.collectgarbage _G.rawset arg.0 utf8.char utf8.codepoint
builtin utf8.offset utf8.charpattern utf8.codes utf8.len debug.upvaluejoin
builtin debug.getupvalue debug.debug debug.getmetatable debug.getuservalue 
builtin debug.sethook debug.traceback debug.setupvalue debug.setmetatable
builtin debug.getlocal debug.gethook debug.setcstacklimit debug.setlocal
builtin debug.getinfo debug.getregistry debug.upvalueid debug.setuservalue 
builtin coroutine.close coroutine.isyieldable coroutine.status coroutine.create
builtin coroutine.running coroutine.wrap coroutine.resume coroutine.yield 
builtin io.lines io.flush io.output io.type io.read io.stdin io.popen io.close
builtin io.stderr io.tmpfile io.stdout io.write io.open io.input math.ldexp
builtin math.randomseed math.exp math.fmod math.mininteger math.pi math.huge
builtin math.ult math.acos math.random math.cos math.frexp math.sin math.log
builtin math.rad math.asin math.maxinteger math.log10 math.type math.cosh
builtin math.sinh math.pow math.tointeger math.tan math.atan2 math.ceil math.abs
builtin math.tanh math.sqrt math.modf math.max math.atan math.deg math.min 
builtin math.floor table.remove table.sort table.insert table.pack table.unpack
builtin table.move table.concat os.exit os.remove os.date os.rename os.getenv
builtin os.setlocale os.clock os.tmpname os.difftime os.time os.execute
?? dotos/resources/tle/wren.vle      ?# wren highlighting

# no multiline comment support because VLE has no state-based highlighting
comment //
keychars []{}()=!&|~-*%.<>^?:+
const true false null
constpat ^%d+$ ^0x[0-9a-zA-Z]+$
constpat ^_.+$ # this is a weird one
keywords as break class construct continue else for foreign if import in is null
keywords return static super this var while
builtin Bool Class Fiber Fn List Map Null Num Object Range Sequence
builtin String System Meta Random
?? dotos/resources/tle/svm.vle       ?# StackVM highlighting because why not

keychars ; : + - / * @ { } [ ] ( ) = , & #
keywords use for in if else dec
builtin printf open read write close hashmap array fn int char float str
?? dotos/resources/tle/vlerc.vle      keywords color co syntax cachelastline macro
builtin co bi bn ct cm is kw kc st op color builtin blank constant comment
builtin insert keyword keychar string black gray lightGray red green yellow blue
builtin magenta cyan white function alias
const on off yes no true false
?? dotos/resources/tle/cpp.vle      }# basic C highlighting

comment //
keychars ()[]*&^|{}=<>;
const true false
constpat ^#.+$
constpat ^%d+$
constpat ^-%d+$
constpat ^0x[a-fA-F0-9]+$
keywords if then else while for
builtin int int32 int64 int32_t int64_t uint uint32 uint64 uint32_t uint64_t
builtin int16 int16_t uint16 uint16_t char struct bool float void ssize_t
builtin uint8 uint8_t int8 int8_t size_t cuint8_t
?? dotos/resources/tle/hc.vle      x# this is an odd language
# i've written highlighting for VLE only because it's stupidly easy to
# get decent results really fast

comment //
constpat ^[%d%.]+$
constpat ^0x[0-9a-fA-F%.]+$
keychars ,=+-/*()
keywords include fn var asm const
builtin nop imm sto ldr psh pop mov add sub div mul lsh rsh xor or not and
builtin jur jun jcr jcn sof cmp dsi eni hdi int prd pwr hlt
?? dotos/resources/tle/c.vle      ?# basic C highlighting

comment //
keychars ()[]{}*;,
operator = + - != == >= <= &= |= || && * += -= /= *= >> << < > -> /
const true false
constpat ^<.+>$
constpat ^#.+$
constpat ^%d+$
constpat ^-%d+$
constpat ^0x[a-fA-F0-9]+$
keywords if then else while for return do break
builtin int int32 int64 int32_t int64_t uint uint32 uint64 uint32_t uint64_t
builtin int16 int16_t uint16 uint16_t char struct bool float void ssize_t
builtin uint8 uint8_t int8 int8_t size_t const unsigned
?? dotos/resources/tle/forth.vle      "# FORTH syntax file
# Only supports the subset of FORTH that is supported by Open Forth

comment \
constpat ^%d+$ ^0x[0-9a-fA-F]$
keychars + * / - . ; : < = >
keywords cr if else then do loop drop dup mod swap i words
builtin power read fread invoke memfree write eval clist split memtotal
?? dotos/resources/tle/py.vle      	?# python.  ugh.

const True False None
comment #
constpat ^%d+$
constpat ^-%d+$
constpat ^0x%x+$
constpat ^0b[01]$
constpat ^0o[0-7]$
keychars []()@
operator = + - / * != += -= /= *= | @ & ^ . : / << > < >>
keywords break for not class from or continue global pass def if raise and del
keywords import return as elif in try assert else is while async except lambda
keywords with await finally nonlocal yield exec
builtin NotImplemented Ellipsis abs all any bin bool bytearray callable chr
builtin classmethod compile complex delattr dict dir divmod enumerate eval filter
builtin float format frozenset getattr globals hasattr hash help hex id input int
builtin isinstance issubclass iter len list locals map max memoryview min next
builtin object oct open ord pow print property range repr reversed round set
builtin setattr slice sorted staticmethod str sum super tuple type vars zip
# python 2 only
builtin basestring cmp execfile file long raw_input reduce reload unichr unicode
builtin xrange apply buffer coerce intern
# python 3 only
builtin ascii bytes exec

# errors!
# builtin BaseException Exception
builtin ArithmeticError BufferError
builtin LookupError
# builtin base exceptions removed in Python 3
builtin EnvironmentError StandardError
# builtin exceptions (actually raised)
builtin AssertionError AttributeError
builtin EOFError FloatingPointError GeneratorExit
builtin ImportError IndentationError
builtin IndexError KeyError KeyboardInterrupt
builtin MemoryError NameError NotImplementedError
builtin OSError OverflowError ReferenceError
builtin RuntimeError StopIteration SyntaxError
builtin SystemError SystemExit TabError TypeError
builtin UnboundLocalError UnicodeError
builtin UnicodeDecodeError UnicodeEncodeError
builtin UnicodeTranslateError ValueError
builtin ZeroDivisionError
# builtin OS exceptions in Python 3
builtin BlockingIOError BrokenPipeError
builtin ChildProcessError ConnectionAbortedError
builtin ConnectionError ConnectionRefusedError
builtin ConnectionResetError FileExistsError
builtin FileNotFoundError InterruptedError
builtin IsADirectoryError NotADirectoryError
builtin PermissionError ProcessLookupError
builtin RecursionError StopAsyncIteration
builtin TimeoutError
# builtin exceptions deprecated/removed in Python 3
builtin IOError VMSError WindowsError
# builtin warnings
builtin BytesWarning DeprecationWarning FutureWarning
builtin ImportWarning PendingDeprecationWarning
builtin ResourceWarning
?? dotos/resources/tle/sh.vle      ?# Basic highlighting for shell scripts

comment #
keychars ={}[]()|><&*:;~/
operator || >> > << < && * : ; ~ /
keywords alias bg bind break builtin caller case in esac cd command compgen
keywords complete compopt continue coproc declare dirs disown echo enable eval
keywords exec exit export fc fg for do done function getopts hash help history
keywords if then elif fi jobs kill let local logout mapfile popd printf pushd
keywords pwd read readarray readonly return select set shift shopt source
keywords suspend test time times trap type typeset ulimit umask unalias unset
keywords until wait while
const true false
constpat ^%-(.+)$
constpat ^([%d.]+)$
constpat ^%$[%w_]+$
?? dotos/resources/tle/vle.vle       ?# VLE highlighting for... VLE

strings off
comment #
keywords operator strings keychars comment keywords const builtin numpat
keywords constpat
?? dotos/resources/tle/md.vle       ~# basic markdown highlighting

strings ` # markdown has no strings, so treat codeblocks as strings.  why not?
keychars -*[]()
?? !dotos/resources/dottk/craftos.lua      local colors = require("colors")
colors.loadPalette("craftos")

return {
  accent_color = colors.blue,
  accent_comp = colors.white,
  base_color = colors.yellow,
  button_color = colors.lightGray,
  text_color = colors.black,
  titlebar = colors.blue,
  titlebar_text = colors.white
}
?? !dotos/resources/dottk/default.lua      ?-- DotTK default color scheme --
local colors = require("colors")
colors.loadPalette("default")

return {
  -- accent color
  accent_color = colors.red,
  -- complement to the accent color
  accent_comp = colors.white,
  -- colors for everything not a button
  base_color = colors.gray,
  base_color_light = colors.lightGray,
  -- text color
  text_color = colors.white,
  -- text while disabled
  text_disabled = colors.lightGray,
  -- button color defaults to accent color
  button_color = colors.gray,
  -- button text color defaults to accent complement
  button_text = colors.white,
  -- titlebar background color defaults to base_color
  titlebar = colors.gray,
  -- titlebar text color defaults to text_color
  titlebar_text = colors.white
}
?? )dotos/resources/dotui/colors/Colorful.lua      local colors = require("colors")

return {
  textcol_default = colors.black,
  textcol_titlebar = colors.white, textcol_close = colors.black,
  
  bg_default = colors.yellow,
  bg_titlebar = colors.blue, bg_close = colors.lightRed,
  
  clickable_text_default = colors.black,
  clickable_bg_default = colors.lightBlue,
  
  switch_on = colors.blue,
  switch_off = colors.gray,
  
  menu_text_default = colors.white,
  menu_bg_default = colors.gray,
  
  selector_selected_fg = colors.white,
  selector_selected_bg = colors.blue,
  selector_unselected_fg = colors.red,
  selector_unselected_bg = colors.lightGray,
  
  drop_shadow = colors.gray,
  
  dropdown_text_default = colors.black,
  dropdown_bg_default = colors.lightBlue,

  scrollbar_color = colors.blue,
  scrollbar_fg = colors.white
}
?? &dotos/resources/dotui/colors/Light.lua      ?local colors = require("colors")

local accent_color = colors.blue

return {
  accent_color = accent_color,
  -- default text color
  textcol_default = colors.black,
  -- titlebar text colors
  textcol_titlebar = colors.white, textcol_close = colors.black,
  -- default background color
  bg_default = colors.white,
  -- titlebar background colors
  bg_titlebar = accent_color, bg_close = colors.lightRed,
  -- default foreground/background color for clickable objects
  clickable_text_default = colors.black,
  clickable_bg_default = colors.lightGray,
  -- background colors for the states of switches
  switch_on = accent_color,
  switch_off = colors.gray,
  -- default foreground/background colors for menu objects
  menu_text_default = colors.white,
  menu_bg_default = colors.gray,
  -- selector button colors (e.g. radiobuttons, checkboxes)
  selector_selected_fg = colors.white,
  selector_selected_bg = accent_color,
  selector_unselected_fg = colors.black,
  selector_unselected_bg = colors.lightGray,
  -- drop shadow color
  drop_shadow = colors.gray,
  -- drop menu colors
  dropdown_text_default = colors.black,
  dropdown_bg_default = colors.lightGray,
  -- scrollbar colors
  scrollbar_color = colors.lightGray,
  scrollbar_fg = colors.gray
}
?? %dotos/resources/dotui/colors/Dark.lua      6local colors = require("colors")

-- see colors/Light for a description of these fields
return {
  textcol_default = colors.white,
  textcol_titlebar = colors.white, textcol_close = colors.black,
  
  bg_default = colors.black,
  bg_titlebar = colors.gray, bg_close = colors.red,
  
  clickable_text_default = colors.white,
  clickable_bg_default = colors.gray,

  switch_on = colors.blue,
  switck_off = colors.gray,

  menu_text_default = colors.white,
  menu_bg_default = colors.gray,

  selector_selected_fg = colors.white,
  selector_selected_bg = colors.blue,
  selector_unselected_fg = colors.lightGray,
  selector_unselected_bg = colors.gray,

  -- no drop shadow

  dropdown_text_default = colors.white,
  dropdown_bg_default = colors.gray,
  
  scrollbar_color = colors.gray,
  scrollbar_fg = colors.lightGray
}
?? dotos/init.lua      J-- .INIT --

local fs = require("fs")
local dotos = require("dotos")

dotos.log("[.init] running startup scripts")

local scripts, err = fs.list("/dotos/startup/")
if not scripts then
  dotos.log("[.init] WARNING: failed getting directory listing")
end
table.sort(scripts)

for i=1, #scripts, 1 do
  dotos.log("[.init] running script %s", scripts[i])
  dofile("/dotos/startup/" .. scripts[i])
end

dotos.log("[.init] starting system interface manager")
dotos.spawn(function()
  dofile("/dotos/core/ifaced.lua")
end, "ifaced")

os.queueEvent("dummy")
while true do coroutine.yield() end
?? init.lua      ?-- DoT OS main initialization file --

local osPath = ...

-- give the option to boot CraftOS, but only if it's present.
-- due to the way ComputerCraft is licensed, i don't ship the
-- BIOS with .OS, but you can put it at /craftos-bios.lua and
-- get the option to load CraftOS from ROM.
if fs.exists("/craftos-bios.lua") then
  local sel = 1
  local timers = {
    [os.startTimer(1)] = 4,
    [os.startTimer(2)] = 3,
    [os.startTimer(3)] = 2,
    [os.startTimer(4)] = 1,
    [os.startTimer(5)] = 0
  }
  local function nl()
    local x,y=term.getCursorPos()
    term.setCursorPos(1,y+1)
  end
  local trem = 5
  while true do
    term.setBackgroundColor(0x8000)
    term.clear()
    term.setTextColor(1)
    term.setCursorPos(1, 1)
    term.write("** .os boot manager **")nl()
    term.write("please select an option")nl()
    term.write("(use W/S for up/down, D to select)")nl()
    term.write("time left: "..trem)nl()nl()
    term.write((sel == 1 and ":: " or "   ") ..
      ".OS (from "..osPath..")")nl()
    term.write((sel == 2 and ":: " or "   ") ..
      "CraftOS (from /craftos-bios.lua)")nl()
    local sig = table.pack(coroutine.yield())
    if sig[1] == "char" then
      if sig[2] == "w" or sig[2] == "s" then
        sel = (sel == 1 and 2) or 1
      elseif sig[2] == "d" then
        if sel == 2 then
          local handle, err = assert(fs.open("/craftos-bios.lua", "r"))
          local data = handle.readAll()
          handle.close()
          assert((loadstring or load)(data, "=/craftos-bios", "t", _G))()
          return
        else
          break
        end
      end
    elseif sig[1] == "timer" then
      trem = timers[sig[2]] or trem
      if trem == 0 then break end
    end
  end
end

local palette = {
  -- black
  [00001] = 0x000000,
  -- dark and light gray
  [00002] = 0x606060,
  [00004] = 0xb0b0b0,
  -- reds
  [00008] = 0xaa0000,
  [00016] = 0xff0000,
  -- greens
  [00032] = 0x00aa00,
  [00064] = 0x00ff00,
  -- blues
  [00128] = 0x0080ff,
  [00256] = 0x66b6ff,
  -- purples
  [00512] = 0x6000aa,
  [01024] = 0x9000ff,
  -- brown and yellow
  [02048] = 0x6030f0,
  [04096] = 0xffff00,
  -- orange and cyan
  [08192] = 0xff8000,
  [16384] = 0x40ffff,
  -- white
  [32768] = 0xFFFFFF
}

-- compatibility with CC:T 1.89.2
table.unpack = table.unpack or unpack

-- package.lua nils out term later
local term = term
for k, v in pairs(palette) do
  term.setPaletteColor(k, v)
end

-- OS API table
_G.dotos = {
  path = "/"..osPath,
  show_logs = true
}
-- this is removed in package.lua later
local dotos = dotos

term.setBackgroundColor(0x1)
term.setTextColor(0x8000)
term.clear()

local w, h = term.getSize()
-- system console logger thingy
local logbuf = {}
local logio
function dotos.log(fmt, ...)
  local msg = string.format(fmt, ...)
  msg = string.format("[%s] %s", os.date("%H:%M:%S",
    math.floor(os.epoch("utc") / 1000)), msg)
  logbuf[#logbuf+1] = msg
  if dotos.show_logs then
    if type(dotos.logio) == "table" then
      pcall(dotos.logio.write, dotos.logio, msg)
    else
      for line in msg:gmatch("[^\n]+") do
        while #line > 0 do
          local ln = line:sub(1, w)
          line = line:sub(#ln + 1)
          term.scroll(1)
          term.setCursorPos(1, h)
          term.write(ln)
        end
      end
    end
  end
  if #logbuf > 4096 then
    table.remove(logbuf, 1)
  end
end

-- return a protected copy of the log buffer
function dotos.getlogs()
  return setmetatable({}, {__index = function(t,k) return logbuf[k] or "" end,
    __len = function() return #logbuf end, __metatable = {}})
end

local function perr(err)
  term.setTextColor(16)
  term.setCursorPos(1, 3)
  term.write("FATAL: " .. err)
  while true do coroutine.yield() end
end


dotos.log("[.os] running from /" .. osPath)

-- argument checking
-- @docs {
-- @header { checkArg }
-- This function provides basic argument checking for all programs running under .OS.
-- @lfunction { 
--   @lfname { checkArg }
--   @lfarg { number n The number of the argument to check }
--   @lfarg { any have The argument to check }
--   @lfarg { string ... The type(s) against which to check the argument }
--   @lfdesc { 
--     Checks whether the argument @monospace { have }'s type is equal to any of the provided types.  If it is not, throws an error.
--   }
-- }
-- }
function checkArg(n, have, ...)
  have = type(have)
  local function check(want, ...)
    if not want then
      return false
    else
      return have == want or check(...)
    end
  end
  if not check(...) then
    local aname
    if type(n) == "number" then
      aname = string.format("#%d", n)
    else
      aname = string.format("'%s'", n)
    end
    error(debug.traceback(string.format("bad argument %s (expected %s, got %s)",
      aname, table.concat({...}, " or "), have), 3))
  end
end

-- if we're running in Lua 5.1, replace load() and remove its legacy things
-- (or, rather, place them in dotos.lua51 (for now), where programs that really
-- need them can access them later).
if _VERSION == "Lua 5.1" then
  dotos.lua51 = {
    load = load,
    loadstring = loadstring,
    setfenv = setfenv,
    getfenv = getfenv,
    unpack = unpack,
    log10 = math.log10,
    maxn = table.maxn
  }

  -- we lock dotos.lua51 behind a permissions wall later, so set it as an
  -- upvalue here
  local lua51 = dotos.lua51

  function _G.load(x, name, mode, env)
    checkArg(1, x, "string", "function")
    checkArg(2, name, "string", "nil")
    checkArg(3, mode, "string", "nil")
    checkArg(4, env, "table", "nil")
    env = env or _G

    local result, err
    if type(x) == "string" then
      result, err = lua51.loadstring(x, name)
    else
      result, err = lua51.load(x, name)
    end
    if result then
      env._ENV = env
      lua51.setfenv(result, env)
    end
    return result, err
  end

  _G.setfenv = nil
  _G.getfenv = nil
  _G.loadstring = nil
  _G.unpack = nil
  _G.math.log10 = nil
  _G.table.maxn = nil
end

-- load io library
local handle, err = fs.open(fs.combine(osPath, "/dotos/libraries/io.lua"), "r")
if not handle then
  perr(err)
end
local data = handle.readAll()
handle.close()
local ok, err = load(data, "=io")
if not ok then
  perr(err)
end
_G.io = ok(osPath)

-- load package library
_G.package = dofile("/dotos/libraries/package.lua")
-- install some more essential functions
local loop = dofile("/dotos/core/scheduler.lua")
dofile("/dotos/core/essentials.lua")

local init, err = loadfile("/dotos/init.lua")
if not init then
  perr(err)
end
dotos.spawn(init, ".init")

os.queueEvent("dummy")
loop()
]=======]
