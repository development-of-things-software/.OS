local args = {...}

for i=1, #args, 1 do
  local handle, err = io.open(args[i], "r")
  if not handle then error(err, 0) end
  print(handle:read("a"))
  handle:close()
end
os.exit()
