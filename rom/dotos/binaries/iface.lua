-- iface: switch interfaces on-the-fly --

local ipc = require("ipc")
local args, opts = require("argparser")(...)

if #args == 0 or opts.help then
  io.stderr:write([[
usage: iface <interface>
Connect to ifaced and switch the system interface
without requiring a reboot.

Copyright (c) 2022 DoT Software under the MIT
license.
]])
  os.exit()
end

local iface = args[1]

local conn = ipc.proxy("ifaced")
local ok, err = conn:start(iface)
if not ok then
  io.stderr:write("\27[91m"..err.."\n")
end
conn.conn:close()

