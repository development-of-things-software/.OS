-- self extracting bootable mtar loader --
-- this is similar to the one used in Cynosure
-- except that it wraps the `fs' api rather than
-- presenting a custom fs tree for the OS to
-- do with that tree what it will.
-- this will only work with an MTAR v1 archive.
-- works by seeking to the first capital "z" in
-- itself, and loading the MTAR data from there.
--
-- must be run from CraftOS.

if not (os.version and os.version():match("CraftOS")) then
  error("This program requires CraftOS", 0)
end

local tree = {__is_a_directory=true}

local handle = assert(fs.open(shell.getRunningProgram(), "rb"))

print([[
This is the DoT OS self-extracting MTAR image.  It is intended for demo purposes only.  If you wish to use DoT OS as a standlone CraftOS replacement, use the provided datapack or install it to your root filesystem with the included installer utility.

Please report bugs with this program at https://github.com/development-of-things-software/.os.

Press RETURN to continue.]])

io.read()

write("Locating system data....")
local x, y = term.getCursorPos()

local offset = 0
repeat
  local c = handle.read(1)
  offset = offset + 1
  term.setCursorPos(x, y)
  term.write(tostring(offset))
until c == "\90" -- this is uppercase z, but putting one of those anywhere else
-- in the file would break this.  it's not a great solution, but it does work.
-- skip the newline immediately following that `z'
write("\n")
assert(handle.read(1) == "\n", "corrupt MTAR data")

local function split_path(path)
  local s = {}
  for _s in path:gmatch("[^\\/]+") do
    if _s == ".." then
      s[#s] = nil
    elseif s ~= "." then
      s[#s+1] = _s
    end
  end
  return s
end

local function add_to_tree(name, offset, len)
  print(name, offset)
  local cur = tree
  local segments = split_path(name)
  if #segments == 0 then return end
  for i=1, #segments - 1, 1 do
    local seg = segments[i]
    cur[seg] = cur[seg] or {__is_a_directory = true}
    cur = cur[seg]
  end
  cur[segments[#segments]] = {offset = offset, length = len}
end

local function read(n, offset)
  if offset then handle.seek("set", offset) end
  return handle.read(n)
end

-- avoid using string.unpack because that's not present in CC 1.89.2
local function bunpack(bytes)
  if not bytes then return nil end
  local result = 0
  for c in bytes--[[:reverse()]]:gmatch(".") do
    result = bit32.lshift(result, 8) + c:byte()
  end
  return result
end

local function read_header()
  handle.read(3) -- skip the MTAR v1 file header
  local namelen = bunpack(handle.read(2))
  local name = handle.read(namelen)
  local flen = bunpack(handle.read(8))
  if not flen then return end
  local foffset = handle.seek()
  handle.seek("cur", flen)
  add_to_tree(name, foffset, flen)
  return true
end

repeat until not read_header()

-- wrap the fs api so that the mtar file is the "root filesystem"
-- TODO: make there still be a way to access the real rootfs - 
--       perhaps put it at /fs or something?
-- TODO: make this emulate more of the `fs' API - currently it
--       only wraps what .OS needs

local function find_node(path)
  local segments = split_path(path)
  local node = tree
  for i=1, #segments, 1 do
    node = node[segments[i]]
    if not node then
      return nil, path .. ": File node does not exist"
    end
  end
  return node
end

local mtarfs = {}
function mtarfs.exists(path)
  return not not find_node(path)
end

function mtarfs.list(path)
  local items = {}
  local node, err = find_node(path)
  if not node then return nil, err end
  for k, v in pairs(node) do
    if k ~= "__is_a_directory" then
      items[#items+1] = k
    end
  end
  return items
end

function mtarfs.getSize(path)
  local node, err = find_node(path)
  if not node then return nil, err end
  return node.length or 0
end

function mtarfs.isDir(path)
  local node, err = find_node(path)
  if not node then return nil, err end
  return not not node.__is_a_directory
end

local readonly = "The filesystem is read-only"

function mtarfs.move()
  error(readonly, 0)
end

function mtarfs.copy()
  error(readonly, 0)
end

function mtarfs.delete()
  error(readonly, 0)
end

function mtarfs.open(file, mode)
  if mode:match("[wa]") then
    return nil, readonly
  end
  if not mode:match("r") then
    error("Invalid mode", 0)
  end
  local node, err = find_node(file)
  if not node then return nil, err end
  if node.__is_a_directory then return nil, "Is a directory" end
  local handle = {}
  local offset = 0
  local data = read(node.length, node.offset)
  function handle.read(num)
    assert(num > 0, "cannot read <=0 bytes")
    if offset == #data then return nil end
    local chunk = data:sub(offset, offset + num - 1)
    offset = offset + num
    return chunk
  end
  function handle.readAll()
    if offset == #data then return nil end
    local chunk = data:sub(offset)
    offset = #data
    return chunk
  end
  function handle.readLine(keepnl)
    if offset == #data then return nil end
    local nxnl = data:find("\n", offset) or #data
    local chunk = data:sub(offset, nxnl)
    offset = nxnl
    if chunk:sub(-1) == "\n" and not keepnl then chunk = chunk:sub(1,-2) end
    return chunk
  end
  function handle.close()
  end
  return handle
end

function mtarfs.find()
  error("fs.find is not supported under MTAR-FS", 0)
end

function mtarfs.attributes(path)
  local node, err = find_node(path)
  if not node then return nil, err end
  return {
    size = node.length or 0,
    isDir = not not node.__is_a_directory,
    isReadOnly = true,
    created = 0,
    modified = 0,
  }
end

function mtarfs.isReadOnly()
  return true
end

print("Starting UnBIOS...")
local handle = assert(mtarfs.open("/unbios.lua", "r"))
local data = handle.readAll()
handle.close()
for k, v in pairs(mtarfs) do
  _G.fs[k] = v
end
assert(load(data, "=unbios", "t", _G))()

--[=======[Z
