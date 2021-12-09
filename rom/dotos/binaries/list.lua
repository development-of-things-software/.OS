-- list --

local args, opts = require("argparser")(...)
local fs = require("fs")
local textutils = require("textutils")

local path = args[1] or dotos.getpwd()
local files = fs.list(path)
table.sort(files)

local out = ""
local x = 0
local len = 0
for i=1, #files, 1 do
  if #files[i] > len then len = #files[i] end
end
for i, file in ipairs(files) do
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
  if x + #file + 3 > 51 then
    x = 0
    out = out .. "\n"
  end
  x = x + #file + 2
  out = out .. file .. "  "
end

print(out)

os.exit()
