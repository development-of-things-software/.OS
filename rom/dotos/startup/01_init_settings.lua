-- initialize the /.dotos.cfg file if it does not exist --

local fs = require("fs")

local keymap = "lwjgl3"
local mcver = tonumber(_HOST:match("%b()"):sub(2,-2):match("1%.(%d+)")) or 0
if mcver <= 12 or _HOST:match("CraftOS%-PC") then
  -- use the 1.12.2 keymap
  keymap = "lwjgl2"
end

local defaultConfig = [[
keyboardLayout="]] .. keymap .. [["
colorScheme="Light"
interface="dotsh"
]]

if not fs.exists("/.dotos.cfg") then
  local handle = assert(io.open("/.dotos.cfg", "w"))
  handle:write(defaultConfig)
  handle:close()
end
