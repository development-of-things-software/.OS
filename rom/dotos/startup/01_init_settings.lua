-- initialize the /.dotos.cfg file if it does not exist --

local fs = require("fs")

local defaultConfig = [[
keyboardLayout="1.12.2"
colorScheme="Light"
interface="DotUI"
]]

if not fs.exists("/.dotos.cfg") then
  local handle = assert(io.open("/.dotos.cfg", "w"))
  handle:write(defaultConfig)
  handle:close()
end
