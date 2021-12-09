-- .SH: a simple shell --

local textutils = require("textutils")
local splitters = require("splitters")
local settings = require("settings")
local fs = require("fs")

print("\27[33m -- \27[93mDoT Shell v0\27[33m -- \27[39m")

local replacements = {
  ["{RED}"] = "\27[91m",
  ["{WHITE}"] = "\27[97m",
  ["{BLUE}"] = "\27[94m",
  ["{YELLOW}"] = "\27[93m",
}

local shpath = settings.get("/.dotsh.cfg", "path") or
  "/dotos/binaries;/user/binaries"
settings.set("/.dotos.cfg", "path", shpath)

local function check(path)
  if fs.exists(path) then
    return path
  elseif fs.exists(path..".lua") then
    return path..".lua"
  end
end

local function resolve(cmd)
  if cmd:sub(1,2) == "./" then
    return check(fs.combine(dotos.getpwd(), (cmd:sub(2))))
  elseif cmd:find("/") then
    return check(cmd)
  else
    for ent in shpath:gmatch("[^;]+") do
      local res = check(fs.combine(ent, cmd))
      if res then return res end
    end
  end
  return nil, "command not found"
end

local function execute(input, capture)
  local tokens = splitters.complex(input)
  local cmd, err = resolve(tokens[1])
  if not cmd then error(err, 0) end
  local cap = ""
  local id = dotos.spawn(function()
    if capture then
      io.output({
        fd = {
          write = function(str) cap = cap .. str end,
          flush = function() end,
          close = function() end
        },
        mode = {w = true}
      })
    end
    dofile(cmd, table.unpack(tokens, 2, tokens.n))
  end, input)
  while dotos.running(id) do coroutine.yield() end
  if capture then return cap else return true end
end

setmetatable(replacements, {__index = function(_, k)
  k = k:sub(2, -2) -- strip outer {}
  if k:sub(1,1) == "." then -- {.cmd bla}: execute command
    return execute(k:sub(2), true)
  elseif k:sub(1,1) == "$" then
    -- {$VAR}: get environment variable
    if k:sub(2,2) == "@" or k:sub(2,2) == "+" then
      -- {$@VAR=VAL}: set environment variable
      -- {$+VAR=VAL}: set environment variable *and* return VAL
      local key, val = k:match("^%$.(.-)=(.+)")
      os.setenv(key, val)
      if k:sub(2,2) == "+" then
        return val
      end
    elseif k:sub(2,2) == "!" then
      -- {$!VAR}: unset environment variable
      os.setenv(k:sub(3), nil)
    else
      return os.getenv(k:sub(2)) or ""
    end
    return ""
  end
end})

local handle = io.open("/user/motd.txt", "r")
if not handle then
  handle = io.open("/dotos/motd.txt", "r")
end
if handle then
  print((handle:read("a")
    :gsub("%b{}", function(k)
      if type(replacements[k]) == "function" then
        return replacements[k]()
      else
        return replacements[k] or k
      end
    end)))
  handle:close()
end

while true do
  io.write(string.format("\27[91;49m%s\27[39m: \27[34m%s\27[33m$\27[39m ",
    dotos.getuser(), dotos.getpwd()))
  local input = io.read()
  input = input:gsub("%b{}", function(k)
      if type(replacements[k]) == "function" then
        return replacements[k]()
      else
        return replacements[k] or k
      end
    end)
  if #input > 0 then
    local ok, err = pcall(execute, input)
    if not ok then
      print(string.format("\27[91m%s\27[39m", err))
    end
  end
end
