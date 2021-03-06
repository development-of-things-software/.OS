-- .SH: a simple shell (library-ified) --

local dotos = require("dotos")
local splitters = require("splitters")
local settings = require("settings")
local fs = require("fs")

local replacements = {
  ["{RED}"]    = "\27[91m",
  ["{WHITE}"]  = "\27[37m",
  ["{BLUE}"]   = "\27[94m",
  ["{YELLOW}"] = "\27[93m",
  ["{ORANGE}"] = "\27[33m",
  ["{GREEN}"]  = "\27[92m",
}

local shpath = settings.get("/.dotsh.cfg", "path") or
  "/dotos/binaries;/user/binaries;/shared/binaries"
settings.set("/.dotsh.cfg", "path", shpath)

local function check(path)
  if fs.exists(path) then
    return path
  elseif fs.exists(path..".lua") then
    return path..".lua"
  end
end

local lib = {}

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
lib.resolve = resolve

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
  edit = "tle"
}

execute = function(input, capture, positional)
  if #input == 0 then return end
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
      local yield = coroutine.yield
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
      local function wrapped_yield(...)
        coroutine.yield = yield
        local result = table.pack(yield(...))
        coroutine.yield = wrapped_yield
        if result[1] == "terminate" then
          error("terminated", 0)
        end
        return table.unpack(result, 1, result.n)
      end
      coroutine.yield = wrapped_yield
      local ok, res = pcall(dofile, cmd, table.unpack(tokens, 2, tokens.n))
      if not ok then err = res end
      dotos.exit()
    end, input)
    while dotos.running(id) do coroutine.yield() end
    if err then error(err, 0) end
    if capture then return cap else return true end
  end
end
lib.execute = execute

-- fancy syntax
setmetatable(replacements, {__index = function(_, k)
  replacements[k] = function()
    replacements[k] = nil
    k = k:sub(2, -2) -- strip outer {}
    if k:sub(1,1) == "." then
      -- {.cmd bla}: execute command and return its output, like bash's $(cmd).
      if k:sub(2,2) == ">" or k:sub(2,2) == "+" then
        -- {.>file cmd bla}: execute command and put its output into 'file',
        --   like unix shells' cmd bla > file
        -- {.+file cmd bla}: do this and still return the output, similar to
        --   the 'tee' command
        local fsp = k:find(" ")
        if not fsp then return "" end
        local file = k:sub(3, fsp - 1)
        local output = execute(k:sub(fsp+1), true)
        local handle, err = io.open(file, "w")
        if not handle then error(err, 0) end
        handle:write(output)
        handle:close()
        return ""
      --[[ these will probably be supported in the future
      elseif k:sub(2,2) == "<" then
        -- {.<file cmd bla}: execute command and put its standard input as
        --   'file'
      elseif k:sub(2,2) == "|" then
        -- {.|foo bar; baz bla}: pipe commands]]
      else
        return execute(k:sub(2), true)
      end
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
        return ""
      elseif k:sub(2,2) == "!" then
        -- {$!VAR}: unset environment variable
        os.setenv(k:sub(3), nil)
      elseif k:sub(2,2) == "?" then
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
  end
  return replacements[k]
end})

function lib.expand(input)
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
  return input
end

return lib
