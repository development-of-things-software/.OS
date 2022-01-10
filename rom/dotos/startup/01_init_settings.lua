-- initialize the /.dotos.cfg file if it does not exist --

local fs = require("fs")

local defaultConfig = [[
colorScheme="Light"
interface="dotsh"
]]

if not fs.exists("/.dotos.cfg") then
  local handle = io.open("/.dotos.cfg", "w")
  if handle then
    handle:write(defaultConfig)
    handle:close()
  end
end
