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
  -- text color
  text_color = colors.white,
  -- button color defaults to accent color
  button_color = colors.red,
  -- button text color defaults to accent complement
  button_text = colors.white,
  -- titlebar background color defaults to base_color
  titlebar = colors.gray
  -- titlebar text color defaults to text_color
  titlebar_text = colors.white
}
