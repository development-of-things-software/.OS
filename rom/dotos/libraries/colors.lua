-- color constants --

local term = require("term")
local fs = require("fs")

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
-- }
local colors = {}
colors.bundled = {}

colors.path = "/dotos/resources/palettes/?.lua;/user/resources/palettes/?.lua;/shared/resources/palettes/?.lua"

function colors.loadPalette(name)
  local palette, order
  if fs.exists(name) then
    palette, order = assert(loadfile(name, nil, {}))()
  else
    local file, err = package.searchpath(name, colors.path)
    if not file then
      return nil, err
    end
    palette, order = assert(loadfile(file, nil, {}))()
  end
  for i=1, 16, 1 do
    colors[order[i]] = 2^(i-1)
    term.setPaletteColor(colors[order[i]], palette[i])
  end
  return true
end

for i=1, 16, 1 do
  colors.bundled[bundled_order[i]] = 2^(i-1)
end

colors.loadPalette("default")

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

function colors.fromBlit(col)
  checkArg(1, col, "string")
  return 2^tonumber(col, 16)
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
