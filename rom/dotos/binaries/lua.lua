-- a lua shell --

local env = setmetatable({}, {__index = _G})

while true do
  io.write("> ")
  local input = io.read()
  local ok, err = load("return " .. input, "t", nil, env)
  if not ok then
    ok, err = load(input, "t", nil, env)
  end
  if not ok then
    print(err)
  else
    local result = table.pack(pcall(ok))
    if not result[1] then
      print(result[2])
    else
      print(table.unpack(result, 2, result.n))
    end
  end
end
