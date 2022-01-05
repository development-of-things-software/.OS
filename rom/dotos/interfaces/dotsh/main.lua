-- .SH: text-based shell for power-users --

local dotos = require("dotos")
local term = require("term")
local sigtypes = require("sigtypes")

local surface = require("surface").new(term.getSize())
surface:resize(surface.w, surface.h + 1)

local stream = require("iostream").wrap(surface)
stream.fd.vt.term = term
io.input(stream)
io.output(stream)
dotos.setio("stderr", stream)

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
