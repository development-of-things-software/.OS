-- some .OS core functions --

local dotos = require("dotos")

-- os library extensions --
function os.sleep(s)
  local tid = os.startTimer(s)
  repeat
    local sig, id = coroutine.yield()
  until sig == "timer" and id == tid
  return true
end

os.exit = dotos.exit
os.setenv = dotos.setenv
os.getenv = dotos.getenv

function os.version()
  return ".OS 0.1"
end

-- print()
function _G.print(...)
  local args = table.pack(...)
  local to_write = ""
  for i=1, args.n, 1 do
    if #to_write > 0 then to_write = to_write .. "\t" end
    to_write = to_write .. tostring(args[i])
  end
  io.write(to_write.."\n")
end
