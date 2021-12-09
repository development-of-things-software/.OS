-- .SH: a simple shell --

print("\27[33m -- \27[93mDoT Shell v0\27[33m -- \27[39m")

local replacements = {
  ["{RED}"] = "\27[91m",
  ["{WHITE}"] = "\27[97m",
  ["{BLUE}"] = "\27[94m",
  ["{YELLOW}"] = "\27[93m"
}

local handle = io.open("/user/motd.txt", "r")
if not handle then
  handle = io.open("/dotos/motd.txt", "r")
end
if handle then
  print((handle:read("a")
    :gsub("%b{}", function(k) return replacements[k] or k end)))
  handle:close()
end

while true do
  io.write(string.format("\27[91;49m%s\27[39m: \27[34m%s\27[39m$ ",
    dotos.getuser(), dotos.getpwd()))
  print("\27[91;107mINPUT\27[39;49m: " .. io.read())
end
