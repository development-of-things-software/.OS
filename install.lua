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

local function download(file)
  local dir = fs.getDir(file)
  dir = fs.combine(installdir, dir)
  fs.makeDir(dir)
  print(file)
  local dl = assert(http.get(base .. file, nil, true))
  local data = dl.readAll()
  dl.close()
  local whand = assert(io.open(fs.combine(installdir, file), "wb"))
  whand:write(data)
  whand:close()
end

for line in handle.readLine do
  download(line)
end

handle.close()

download("unbios.lua")
fs.move(fs.combine(installdir, "unbios.lua"), fs.combine(installdir, "startup.lua"))
