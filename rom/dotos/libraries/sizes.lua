-- size formatting --

local lib = {}

local exts = {
  "", "K", "M", "G", "T"
}

function lib.formatSized(num, div)
  checkArg(1, num, "number")
  checkArg(2, div, "number")
  local i = 1
  while num > div do
    num = num / div
    i = i + 1
  end
  return string.format("%.2f%s", num, exts[i])
end

function lib.format1024(num)
  checkArg(1, num, "number")
  return lib.formatSized(num, 1024)
end

function lib.format1000(num)
  checkArg(1, num, "number")
  return lib.formatSized(num, 1000)
end

lib.format = lib.format1024

return lib
