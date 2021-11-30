-- boot splash screen -

do return end
dotos.show_logs = nil

local term = require("term")
local colors = require("colors")

term.setBackgroundColor(colors.lightBlue)
term.clear()
term.setCursorBlink(false)

local function fill(x,y,w,h)
  local str = (" "):rep(w)
  for i=1, h, 1 do
    term.setCursorPos(x, y+i-1)
    term.write(str)
  end
end

local w, h = term.getSize()
local text = {
  os.version(),
  "  by DoT Software"
}
local box = {
  x = math.floor(w / 2) - 8,
  y = math.floor(h / 2) - 2,
  w = 19,
  h = 4
}

term.setBackgroundColor(colors.gray)
fill(box.x+1, box.y+1, box.w, box.h)

term.setBackgroundColor(colors.lightGray)
fill(box.x, box.y, box.w, box.h)
term.setTextColor(colors.black)
for i, line in ipairs(text) do
  term.setCursorPos(box.x+1, box.y+i)
  term.write(line)
end

