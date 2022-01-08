-- DotTK default color scheme --
local colors = require("colors")
colors.loadPalette("default")

return {
  -- accent color
  accent_color = colors.red,
  -- complement to the accent color
  accent_comp = colors.white,
  -- colors for everything not a button
  base_color = colors.gray,
  -- button color defaults to accent color
  button_color = colors.red,
  -- text color
  text_color = colors.white,
  -- titlebar background color defaults to base_color
  titlebar = colors.gray
  -- titlebar text color defaults to text_color
  titlebar_text = colors.white
}
