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

local execute
local builtins = {
  resolve = function(c, path)
    local res, err = resolve(path)
    if not res then error("resolution error: " .. err, 0) end
    if c then return res else print(res) return true end
  end,
  cd = function(c, dir)
    dir = dir or "/user"
    local ok, err = dotos.setpwd(dir)
    if not ok and err then error(err, 0) end
    return c and "" or ok
  end,
  pwd = function(c)
    if c then return dotos.getpwd() else print(dotos.getpwd()) end
  end,
  exit = function() dotos.exit() end,
  chuser = function(_, name)
    local ok, err = dotos.setuser(name)
    if not ok and err then error(err, 0) end
    return true
  end,
  echo = function(c, ...)
    local text = table.concat(table.pack(...), " ")
    if c then return text else print(text) end
  end,
  source = function(c, file, ...)
    local args = {...}
    return execute("{.cat " .. file .. "}", c, {...})
  end
}

local aliases = {
  ls = "list",
  rm = "delete",
}

execute = function(input, capture, positional)
  local tokens = splitters.complex(input)
  local cmd = tokens[1]
  if aliases[cmd] then cmd = aliases[cmd] end
  if builtins[cmd] then
    return builtins[cmd](capture, table.unpack(tokens, 2, tokens.n))
  else
    local cmd, err = resolve(cmd)
    if not cmd then error(err, 0) end
    local cap, err = ""
    local id = dotos.spawn(function()
      if capture then
        io.output(
          dotos.mkfile({
            read = function() end,
            readLine = function() end,
            readAll = function() end,
            write = function(str) cap = cap .. str end,
            flush = function() end,
            close = function() end
          }, "w"))
      end
      if positional then
        for i=1, #positional, 1 do
          os.setenv(tostring(i), positional[i])
        end
      end
      local ok, res = pcall(dofile, cmd, table.unpack(tokens, 2, tokens.n))
      if not ok then err = res end
      dotos.exit()
    end, input)
    while dotos.running(id) do coroutine.yield() end
    if err then error(err, 0) end
    if capture then return cap else return true end
  end
end

-- fancy syntax
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
    elseif k == "$?" then
      -- {$?}: all environment variables
      local env = os.getenv()
      local lines = {}
      for k,v in pairs(env) do
        lines[#lines+1] = k .. "=" .. v
      end
      table.sort(lines)
      return table.concat(lines, "\n")
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
  io.write(string.format("\27[33;49m%s\27[39m: \27[34m%s\27[33m$\27[39m ",
    dotos.getuser(), dotos.getpwd()))
  local input = io.read()
  input = input:gsub("%b{}", function(k)
      if type(replacements[k]) == "function" then
        return replacements[k]()
      else
        return replacements[k] or k
      end
    end)
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
