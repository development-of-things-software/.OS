-- .SH: a simple shell --

local dotos = require("dotos")
local dotsh = require("dotsh")
local readline = require("readline")

local handle = io.open("/user/motd.txt", "r")
if not handle then
  handle = io.open("/dotos/motd.txt", "r")
end
if handle then
  print(dotsh.expand(handle:read("a")))
  handle:close()
end

os.setenv("SHLVL", (os.getenv("SHLVL") or 0) + 1)

local function drawprompt()
  io.write(string.format("\27[93;49m%s\27[39m: \27[94m%s\27[93m$\27[39m ",
    dotos.getuser(), dotos.getpwd()))
end

local hist = {}
local rlopts = {history = hist, exit = os.exit}
while true do
  drawprompt()
  local input = readline(rlopts)

  if #input > 0 then
    table.insert(hist, input)
    input = dotsh.expand(input)
    local ok, err = pcall(dotsh.execute, input)
    if not ok then
      print(string.format("\27[91m%s\27[39m", err))
    end
  end
end
