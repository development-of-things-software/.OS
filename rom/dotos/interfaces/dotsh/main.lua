-- .SH: text-based shell for power-users --

local term = require("term")
local sigtypes = require("sigtypes")

local surface = require("surface").new(term.getSize())

local stream = require("iostream").wrap(surface)
io.input(stream)
io.output(stream)

dotos.spawn(function()
  dofile("/rom/dotos/binaries/dotsh.lua")
end, ".SH")

-- the IO stream has its own "cursor", so disable the default CC one
term.setCursorBlink(false)
stream:write(".SH v0\n")
dotos.logio = stream
while true do
  surface:draw(1,1)
  coroutine.yield()
end
