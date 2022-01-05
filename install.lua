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

for line in handle.readLine do
  local dir = fs.getDir(line)
  dir = fs.combine(installdir, dir)
  fs.makeDirectory(dir)
  print(line)
  local dl = assert(http.get(base .. line, nil, true))
  local data = dl.readAll()
  dl.close()
  local whand = io.open(fs.combine(installdir, line), "wb")
  whand:write(data)
  whand:close()
end
