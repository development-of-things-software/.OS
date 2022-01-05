-- DOT-OS BIOS --

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
