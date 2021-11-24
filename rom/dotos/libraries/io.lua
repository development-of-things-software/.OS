-- io library --

local osPath = ...

-- the package library nils _G.fs later, so keep it here
local fs = fs

-- split a file path into segments
local function split(path)
  local s = {}
  for S in path:gmatch("[^/\\]+") do
    if S == ".." then
      s[#s] = nil
    elseif S ~= "." then
      s[#s+1] = S
    end
  end
  return s
end

-- override the fs library to use this resolution function where necessary
do
  -- path resolution:
  -- if the path begins with /dotos, then redirect to wherever that actually
  -- is; otherwise, resolve the path based on the current program's working
  -- directory
  -- this is to allow .OS to run from anywhere
  local function resolve(path)
    local root = (dotos.getroot and dotos.getroot()) or "/"
    local pwd = (dotos.getpwd and dotos.getpwd()) or "/"
    if path:sub(1,1) ~= "/" then
      path = fs.combine(pwd, path)
    end
    path = fs.combine(root, path)
    local segments = split(path)
    if segments[1] == "dotos" then
      return "/" .. fs.combine(osPath, path)
    else
      return "/" .. path
    end
  end

  -- override: fs.list
  local list = fs.list
  function fs.list(path)
    checkArg(1, path, "string")
    path = resolve(path)
    local files = list(path)
    if path == "/" then
      -- inject /dotos into the root listing
      files[#files+1] = "dotos"
    end
    return files
  end

  -- override: fs.getSize
  local getSize = fs.getSize
  function fs.getSize(path)
    checkArg(1, path, "string")
    return getSize(resolve(path))
  end

  -- override: fs.exists
  local exists = fs.exists
  function fs.exists(path)
    checkArg(1, path, "string")
    return exists(resolve(path))
  end

  -- override: fs.isDir
  local isDir = fs.isDir
  function fs.isDir(path)
    checkArg(1, path, "string")
    return isDir(resolve(path))
  end
  
  -- override: fs.makeDir
  local makeDir = fs.makeDir
  function fs.makeDir(path)
    checkArg(1, path, "string")
    return makeDir(resolve(path))
  end
  
  -- override: fs.move
  local move = fs.move
  function fs.move(a, b)
    checkArg(1, a, "string")
    checkArg(2, b, "string")
    return move(resolve(a), resolve(b))
  end
  
  -- override: fs.copy
  local copy = fs.copy
  function fs.copy(a, b)
    checkArg(1, a, "string")
    checkArg(2, b, "string")
    return copy(resolve(a), resolve(b))
  end

  -- override: fs.delete
  local delete = fs.delete
  function fs.delete(path)
    checkArg(1, path, "string")
    return delete(resolve(path))
  end

  -- override: fs.open
  local open = fs.open
  function fs.open(file, mode)
    checkArg(1, file, "string")
    checkArg(2, mode, "string")
    return open(resolve(file), mode)
  end

  -- override: fs.find
  local find = fs.find
  function fs.find(path)
    checkArg(1, path, "string")
    return find(resolve(path))
  end

  -- override: fs.attributes
  local attributes = fs.attributes
  function fs.attributes(path)
    checkArg(1, path, "string")
    return attributes(resolve(path))
  end
end

local io = {}

setmetatable(io, {__index = function(t, k)
  if k == "stdin" then
    return dotos.getio("stdin")
  elseif k == "stdout" then
    return dotos.getio("stdout")
  elseif k == "stderr" then
    return dotos.getio("stderr")
  end
  return nil
end, __metatable = {}})

local function fread(f, ...)
  checkArg(1, f, "table")
  local fmt = table.pack(...)
  local results = {}
  local n = 0
  if fmt.n == 0 then fmt[1] = "l" end

  if not f.mode.r then
    return nil, "bad file descriptor"
  end
  
  for i, fmt in ipairs(fmt) do
    fmt = fmt:gsub("%*", "")
    n = n + 1
    if fmt == "n" then
      error("bad argument to 'read' (format 'n' not supported)")
    elseif fmt == "a" then
      results[n] = f.fd.readAll()
    elseif fmt == "l" or fmt == "L" then
      results[n] = f.fd.readLine(fmt == "L")
    elseif type(fmt) == "number" then
      results[n] = f.fd.read(fmt)
    else
      error("bad argument to 'read' (invalid format '"..fmt.."')")
    end
  end

  return table.unpack(results, 1, n)
end

local function fwrite(f, ...)
  checkArg(1, f, "table")
  
  if not (f.mode.w or f.mode.a) then
    return nil, "bad file descriptor"
  end
  
  local towrite_raw = table.pack(...)
  local towrite = ""
  
  for i, write in ipairs(towrite_raw) do
    checkArg(i+1, write, "string")
    towrite = towrite .. write
  end
  
  f.fd.write(towrite)
  
  return f
end

local function fseek(f, whence, offset)
  checkArg(1, f, "table")
  checkArg(2, whence, "string")
  checkArg(3, offset, "number")
  if not f.fd.seek then
    return nil, "bad file descriptor"
  end
  local ok, err = f.fd.seek(whence, offset)
  if not ok then return nil, err end
  return ok
end

local function fflush(f)
  checkArg(1, f, "table")
  if not (f.mode.w or f.mode.a) then
    return nil, "bad file descriptor"
  end
  f.fd.flush()
  return f
end

local function fclose(f)
  checkArg(1, f, "table")
  f.closed = true
  return f.fd.close()
end

function dotos.mkfile(handle, mode)
  local _mode = {}
  for c in mode:gmatch(".") do
    _mode[c] = true
  end
  return {
    mode = _mode,
    fd = handle,
    read = fread,
    flush = fflush,
    write = fwrite,
    seek = fseek,
    close = fclose,
    lines = io.lines
  }
end

function io.open(file, mode)
  checkArg(1, file, "string")
  checkArg(2, mode, "string", "nil")
  mode = mode or "r"
  if not fs.exists(file) then
    return nil, file .. ": no such file or directory"
  end
  local handle, err = fs.open(file, mode)
  if not handle then
    return nil, file .. ": " .. err
  end
  return dotos.mkfile(handle, mode)
end

function io.read(...)
  return io.stdin:read(...)
end

function io.write(...)
  return io.stdout:write(...)
end

function io.flush()
end

function io.type(f)
  if not f then return nil end
  if type(f) ~= "table" then return nil end
  if not (f.fd and f.mode and f.read and f.write and f.seek and f.close) then
    return nil end
  return f.closed and "closed file" or "file"
end

function io.close(f)
  f = f or io.stdout
  return f:close()
end

-- loadfile and dofile here as well
function _G.loadfile(file, mode, env)
  checkArg(1, file, "string")
  checkArg(2, mode, "string", "nil")
  checkArg(3, env, "table", "nil")
  local handle, err = io.open(file, "r")
  if not handle then
    return nil, file .. ": " .. err
  end
  local data = handle:read("a")
  handle:close()
  return load(data, "="..file, "bt", env)
end

function _G.dofile(file, ...)
  checkArg(1, file, "string")
  local func, err = loadfile(file)
  if not func then
    error(err)
  end
  return func(...)
end

return io
