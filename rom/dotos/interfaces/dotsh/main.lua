-- .SH: text-based shell for power-users --

local term = require("term")

local surface = require("surface").new(term.getSize())

local stream = require("iostream").wrap(surface)
io.input(stream)
io.output(stream)

dotos.spawn(function()
  dofile("/rom/dotos/binaries/dotsh.lua")
end, ".SH")

-- the IO stream has its own "cursor", so disable the default CC one
term.setCursorBlink(false)
while true do
  surface.blit()
  coroutine.yield()
end
