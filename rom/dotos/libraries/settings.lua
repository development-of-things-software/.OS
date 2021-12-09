-- settings management --

local function serialize(k, v)
  checkArg(1, k, "string")
  checkArg(2, v, "string", "number", "boolean", "nil")
  return string.format("%s=%q\n", k, v)
end

local function coerce(k)
  if k == "true" then return true end
  if k == "false" then return false end
  if k == "nil" then return nil end
  if k:sub(1,1) == '"' then k = k:sub(2,-2) end
  return tonumber(k) or k
end

local function unserialize(line)
  local k, v = line:match("(.-)=(.+)")
  return k, coerce(v)
end

local lib = {}

function lib.load(file)
  checkArg(1, file, "string")
  local handle, err = io.open(file, "r")
  if not handle then return {}, err end
  local cfg = {}
  for line in handle:lines() do
    local k, v = unserialize(line)
    if k and v then cfg[k] = v end
  end
  handle:close()
  return cfg
end

function lib.save(file, cfg)
  checkArg(1, file, "string")
  checkArg(2, cfg, "table")
  local handle = assert(io.open(file, "w"))
  for k,v in pairs(cfg) do
    handle:write(serialize(k,v))
  end
  handle:close()
end

function lib.get(file, k)
  return lib.load(file)[k]
end

function lib.set(file, k, v)
  local c = lib.load(file)
  c[k] = v
  lib.save(file, c)
end

-- system settings functions
local file = "/.dotos.cfg"
function lib.sysget(k)
  return lib.get(file, k)
end

function lib.sysset(k, v)
  return lib.set(file, k, v)
end

return lib
