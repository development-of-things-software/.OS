-- color constants --

local order = {
  "black",
  "gray",   "lightGray",
  "red",    "lightRed",
  "green",  "lightGreen",
  "blue",   "lightBlue",
  "purple", "magenta",
  "brown",  "yellow",
  "orange", "cyan",
  "white"
}

-- the CraftOS color set is designed to match bundled cables, so provide
-- that set of colors here too
local bundled_order = {
  "white", "orange", "magenta", "lightBlue", "yellow",
  "lime", "pink", "gray", "lightGray", "cyan", "purple",
  "blue", "brown", "green", "red", "black"
}

--@docs {
--@header { Colors }
--Provides named constants for all the terminal's palette colors, plus some other useful functions.
--
--@header2 { Fields }
--@monospace { colors.bundled: @green { table } }
--  Provides all the CraftOS color constants for use with bundled cables, and bundled cables @italic { only }.
--
--
-- }
local colors = {}
colors.bundled = {}
for i=1, 16, 1 do
  colors[order[i]] = 2^(i-1)
  colors.bundled[bundled_order[i]] = 2^(i-1)
end

local blit_colors = {}
for i=1, 16, 1 do
  blit_colors[2^(i-1)] = string.format("%x", i - 1)
end

function colors.bundled.combine(...)
  local result = 0
  for i, color in ipairs(table.pack(...)) do
    checkArg(i, color, "number")
    result = bit32.bor(result, color)
  end
  return result
end

function colors.bundled.remove(combination, ...)
  checkArg(1, combination, "number")
  local result = combination
  for i, color in ipairs(table.pack(...)) do
    checkArg(i+1, color, "number")
    result = bit32.band(result, bit32.bnot(color))
  end
  return result
end

function colors.bundled.test(combination, color)
  checkArg(1, combination, "number")
  checkArg(2, color, "number")
  return bit32.band(combination, color) == color
end

function colors.toBlit(col)
  checkArg(1, col, "number")
  return blit_colors[col]
end

function colors.pack(r, g, b)
  checkArg(1, r, "number")
  checkArg(2, g, "number")
  checkArg(3, b, "number")
  return r * 0x10000 + g * 0x100 + b
end

function colors.unpack(rgb)
  checkArg(1, rgb, "number")
  return
    bit32.rshift(bit32.band(rgb, 0xff0000), 16),
    bit32.rshift(bit32.band(rgb, 0x00ff00), 8),
    bit32.band(rgb, 0x0000ff)
end

return colors
