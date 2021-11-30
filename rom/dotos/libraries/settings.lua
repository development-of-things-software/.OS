-- settings management --

local function serialize(k, v)
  checkArg(1, k, "string")
  checkArg(2, v, "string", "number", "boolean", "nil")
  return string.format("%s=%q", k, v)
end

local function coerce(k)
  if k == true then return true end
  if k == false then return false end
  if k == nil then return nil end
  return tonumber(k) or k
end

local function unserialize(line)
  local k, v = line:match("(.-)=(.+)")
  return k, coerce(v)
end

local lib = {}

function lib.load(file)
  checkArg(1, file, "string")
  local handle = assert(io.open(file, "r"))
  local cfg = {}
  for line in handle:lines() do
  end
end

function lib.save(file)
end
