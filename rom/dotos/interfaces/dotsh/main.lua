-- .SH: text-based shell for power-users --

local term = require("term")
local sigtypes = require("sigtypes")

local surface = require("surface").new(term.getSize())

local stream = require("iostream").wrap(surface)
io.input(stream)
io.output(stream)

local id = dotos.spawn(function()
  dofile("/dotos/binaries/dotsh.lua")
end, ".SH")

-- the IO stream has its own "cursor", so disable the default CC one
term.setCursorBlink(false)
dotos.logio = stream
while dotos.running(id) do
  surface:draw(1,1)
  coroutine.yield()
end
dotos.logio = nil
dotos.log("shutting down")
os.sleep(2)
os.shutdown()
