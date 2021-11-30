local colors = require("colors")

local accent_color = colors.blue

return {
  accent_color = accent_color,
  -- default text color
  textcol_default = colors.black,
  -- titlebar text colors
  textcol_titlebar = colors.white, textcol_close = colors.black,
  -- default background color
  bg_default = colors.white,
  -- titlebar background colors
  bg_titlebar = accent_color, bg_close = colors.lightRed,
  -- default foreground/background color for clickable objects
  clickable_text_default = colors.black,
  clickable_bg_default = colors.lightGray,
  -- background colors for the states of switches
  switch_on = accent_color,
  switch_off = colors.gray,
  -- default foreground/background colors for menu objects
  menu_text_default = colors.white,
  menu_bg_default = colors.gray,
  -- selector button colors (e.g. radiobuttons, checkboxes)
  selector_selected_fg = colors.white,
  selector_selected_bg = accent_color,
  selector_unselected_fg = colors.black,
  selector_unselected_bg = colors.lightGray,
  -- drop shadow color
  drop_shadow = colors.gray,
  -- drop menu colors
  dropdown_text_default = colors.black,
  dropdown_bg_default = colors.lightGray,
  -- scrollbar colors
  scrollbar_color = colors.lightGray,
  scrollbar_fg = colors.gray
}
