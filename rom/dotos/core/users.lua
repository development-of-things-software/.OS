-- a proper user system --

local lib = {}

local dotos = require("dotos")
local fs = require("fs")
local settings = require("settings")
local hash = dofile("/dotos/core/sha256.lua").digest

local ucfg = "/.users.cfg"

local function ensure()
  if not fs.exists(ucfg) or not settings.get(ucfg, "admin") then
    settings.set(ucfg, "admin", tostring(hash("admin")))
  end
end

function lib.auth(name, pw)
  checkArg(1, name, "string")
  checkArg(2, pw, "string")
  if not lib.exists(name) then
    return nil, "that user does not exist"
  end
  return settings.get(ucfg, name) == tostring(hash(pw))
end

local threads = {}
function lib.threads(t)
  lib.threads = nil
  threads = t
end

function lib.runas(name, pw, ...)
  if not lib.auth(name, pw) then
    return nil, "bad credentials"
  end
  local old = dotos.getuser()
  threads[dotos.getpid()].user = name
  local result = table.pack(pcall(dotos.spawn, ...))
  threads[dotos.getpid()].user = old
  return assert(table.unpack(result, 1, result.n))
end

function lib.exists(name)
  checkArg(1, name, "string")
  ensure()
  return not not settings.get(ucfg, name)
end

return lib
