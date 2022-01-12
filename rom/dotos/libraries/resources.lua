-- resource loader --

local path = "/dotos/resources/?.lua;/shared/resources/?.lua"

local lib = {}

function lib.load(name)
  checkArg(1, name, "string")
  local path = package.searchpath(name, path)
  if not path then return nil, "Resource not found" end
  return dofile(path)
end

return lib
