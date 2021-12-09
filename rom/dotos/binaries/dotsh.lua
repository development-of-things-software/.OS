-- .SH: a simple shell --

print("\27[93mDoT Shell v0\27[39m")

while true do
  io.write("$ ")
  print("INPUT: " .. io.read())
end
