local file = ...
if not file then return end

local name = require("fs").getName(file)
local handle = assert(io.open(file, "r"))
local lines = require("textutils").lines(handle:read("a"))
handle:close()
local printed = 0
for i=1, #lines, 1 do
  print(lines[i])
  printed = printed + math.max(1, #lines[i] / 51)
  if printed % 15 == 0 then
    io.write("\27[33m-- " .. name .. " - press Enter for more --\27[39m")
    io.read()
  end
end
