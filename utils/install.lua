-- Installer for .OS --

local fs = fs or require("fs")
local http = http or require("http")

local installdir = ...

if not installdir then
  io.stderr:write("please pass an install directory (e.g. /disk)\n")
  return
end

local base = "https://raw.githubusercontent.com/development-of-things-software/.os/primary/"

-- get file list
local handle = assert(http.get(base .. "files.txt"))

local total, downloaded = 0, 0

term.clear()
term.setCursorPos(1,1)
local function download(file)
  -- strip /rom
  local ofile = file
  file = file:gsub("/rom", "")
  local dir = fs.getDir(file)
  dir = fs.combine(installdir, dir)
  fs.makeDir(dir)
  local dl = assert(http.get(base .. ofile, nil, true))
  local data = dl.readAll()
  dl.close()
  local whand = assert(io.open(fs.combine(installdir, file), "wb"))
  whand:write(data)
  whand:close()
  downloaded = downloaded + 1
  term.setCursorPos(1, 1)
  term.write("Downloading .OS (%d/%d)", downloaded, total)
end

local files = {}
for line in handle.readLine do
  table.insert(files, function()
    download(line)
  end)
  total = total + 1
end

handle.close()

parallel.waitForAll(table.unpack(files))

download("unbios.lua")
fs.move(fs.combine(installdir, "unbios.lua"), fs.combine(installdir, "startup.lua"))

fs.makeDir(fs.combine(installdir, "/users/admin"))

print("\nInstall finished.")
