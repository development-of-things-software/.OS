local dotos = require("dotos")
local users = require("users")
local rl = require("readline")
while true do
  print("\27[2J\27[H\n\27[33m ## \27[93m.OS Login\27[33m ##\27[39m\n")
  io.write("Username: ")
  local name = rl()
  io.write("Password: \27[8m")
  local pw = io.read("l")
  io.write("\27[m\n\n")
  local pid, err = users.runas(name, pw,
    assert(loadfile("/dotos/binaries/dotsh.lua")), ".SH")
  if not pid then
    print("\27[91m" .. err .. "\27[39m")
    os.sleep(3)
  else
    repeat coroutine.yield() until not dotos.running(err)
  end
end
