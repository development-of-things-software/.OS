local args, opts = require("argparser")(...)
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

local printed = 0
for _,file in ipairs(args) do
  local name = require("fs").getName(file)
  local handle = assert(io.open(file, "r"))
  local lines = require("textutils").lines(handle:read("a"))
  handle:close()
  for i=1, #lines, 1 do
    if opts.E then
      lines[i] = dotsh.expand(lines[i])
    end
    print(lines[i])
    printed = printed + math.max(1, #lines[i] / 51)
    if printed % 15 == 0 then
      io.write("\27[33m-- " .. name .. " - press Enter for more --\27[39m")
      io.read()
    end
  end
end
