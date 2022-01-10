-- view logs --

local logs = require("dotos").getlogs()
local tutils = require("textutils")
local w, h = require("term").getSize()
local printed = 0
for i=1, #logs, 1 do
  for _, line in ipairs(tutils.wordwrap(logs[i], w)) do
    print(line)
    printed = printed + 1
    if printed > h - 2 then
      io.write("[ press Return for more ]")
      io.read()
      io.write("\27[A\27[2K")
      printed = 0
    end
  end
end
