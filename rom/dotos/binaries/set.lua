-- set --

local args, opts = require("argparser")(...)
local settings = require("settings")

local file = "/.dotos.cfg"

if opts.f then
  file = table.remove(args, 1)
end

if #args == 0 or #args > 2 then
  error("usage: set [-f file] KEY [VALUE]", 0)
elseif #args == 1 then
  print(args[1] .. " = " .. tostring(settings.get(file, args[1])))
else
  settings.set(file, args[1], args[2])
  print(args[1] .. " = " .. tostring(settings.get(file, args[1])))
end
