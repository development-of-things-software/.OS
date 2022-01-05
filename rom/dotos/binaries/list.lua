-- list --

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
