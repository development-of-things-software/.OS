local args = {...}

if #args == 0 then
  for name in pairs(require("settings").load("/.users.cfg")) do print(name) end
  return
end
require("fs").makeDir("/users/"..args[1])
require("settings").set("/.users.cfg", args[1], args[2] or "thing")

os.exit()
