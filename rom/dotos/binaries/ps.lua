print("TID  NAME")
for i, thread in ipairs(require("dotos").listthreads()) do
  print(string.format("%4d %s", thread.id, thread.name))
end
