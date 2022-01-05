-- package library --

local package = {}

package.config = "/\n;\n?\n!\n-"
package.cpath = ""
package.path = "/dotos/libraries/?.lua;/user/libraries/?.lua"
package.loaded = {
  _G = _G,
  io = io,
  os = os,
  math = math,
  utf8 = utf8,
  table = table,
  debug = debug,
  bit32 = bit32,
  string = string,
  package = package,
  coroutine = coroutine,
}
package.preload = {}

package.searchers = {
  -- check package.preload
  function(mod)
    if package.preload[mod] then
      return package.preload[mod]
    else
      return nil, "no field package.preload['" .. mod .. "']"
    end
  end,
  -- check for lua library
  function(mod)
    local ok, err = package.searchpath(mod, package.path, ".", "/")
    if not ok then
      return nil, err
    end
    local func, aerr = loadfile(ok)
    if not func then
      return nil, aerr
    end
    return func()
  end
}

local fs = fs
local term = term
local function remove(k)
  package.loaded[k] = _G[k]
  _G[k] = nil
end
for _, api in ipairs({"fs", "term", "http", "peripheral", "periphemu",
    "mounter", "config", "redstone", "dotos"}) do
  remove(api)
end

function package.searchpath(name, path, sep, rep)
  checkArg(1, name, "string")
  checkArg(2, path, "string")
  checkArg(3, sep, "string", "nil")
  checkArg(4, rep, "string", "nil")

  sep = "%" .. (sep or ".")
  rep = rep or "/"

  name = name:gsub(sep, rep)
  local serr = ""

  for search in path:gmatch("[^;]+") do
    search = search:gsub("%?", name)
    if fs.exists(search) then
      return search
    else
      if #serr > 0 then
        serr = serr .. "\n  "
      end
      serr = serr .. "no file '" .. search .. "'"
    end
  end

  return nil, serr
end

function _G.require(mod)
  checkArg(1, mod, "string")

  if package.loaded[mod] then
    return package.loaded[mod]
  end

  local serr = "module '" .. mod .. "' not found:"
  for _, searcher in ipairs(package.searchers) do
    local result, err = searcher(mod)
    if result then
      package.loaded[mod] = result
      return result
    else
      serr = serr .. "\n  " .. err
    end
  end

  error(serr, 2)
end

return package
