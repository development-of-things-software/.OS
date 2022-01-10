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

local w, h = require("termio").getTermSize()

local printed = 0
for _, file in ipairs(args) do
  local name = require("fs").getName(file)
  local handle = assert(io.open(file, "r"))
  local data = handle:read("a")
  handle:close()
  if opts.E then
    data = dotsh.expand(data)
  end
  local lines = require("textutils").lines(data)
  for i=1, #lines, 1 do
    print(lines[i])
    printed = printed + math.max(1,
      math.ceil(#lines[i]:gsub("\27%[[%d;]*%a", "") / w))
    if printed >= h - 3 then
      io.write("\27[33m-- " .. name .. " - press Enter for more --\27[39m")
      io.read()
      io.write("\27[A\27[2K")
      printed = 0
    end
  end
end
