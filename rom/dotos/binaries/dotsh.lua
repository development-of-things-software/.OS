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

local hist = {}
local rlopts = {history = hist, exit = os.exit}
while true do
  io.write(string.format("\27[33;49m%s\27[39m: \27[34m%s\27[33m$\27[39m ",
    dotos.getuser(), dotos.getpwd()))
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
