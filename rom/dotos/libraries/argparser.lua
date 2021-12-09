-- basic argument parser --

return function(...)
  local _args = table.pack(...)
  local args = {}
  local opts = {}
  for i, arg in ipairs(_args) do
    if arg:sub(1,1) == "-" then opts[arg:sub(2)] = true
    else args[#args+1] = arg end
  end
  return args, opts
end
