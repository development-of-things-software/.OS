-- DOT-OS BIOS --

term.clear()
local y = 0
local w, h = term.getSize()

local function tprintf(fmt, ...)
  local ftext = string.format(fmt, ...)
  for text in ftext:gmatch("[^\n]+") do
    while #text > 0 do
      local ln = text:sub(1, w)
      text = text:sub(#ln + 1)
      if y == h then
        term.scroll(1)
      else
        y = y + 1
      end
      term.setCursorPos(1, y)
      term.write(ln)
    end
  end
end

tprintf("DoT Software BIOS version 0.1.0")
tprintf(" - by Ocawesome101")
tprintf("")

local loadstr = load
if _VERSION == "Lua 5.1" then
  loadstr = loadstring
end

tprintf("Probing boot files...")

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
  local ok, traceback = xpcall(ok, debug.traceback)
  if not ok and traceback then
    err("failed executing file %s: %s", file, traceback)
  end
  os.shutdown()
  while true do coroutine.yield() end
end

local function checkFile(f)
  if fs.exists(f) then
    boot(f)
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
