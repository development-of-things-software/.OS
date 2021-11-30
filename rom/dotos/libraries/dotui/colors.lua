local colors = require("colors")

return {
  -- default text color
  textcol_default = colors.black,
  -- titlebar text colors
  textcol_titlebar = colors.white, textcol_close = colors.black,
  -- default background color
  bg_default = colors.white,
  -- titlebar background colors
  bg_titlebar = colors.blue, bg_close = colors.red,
  -- default foreground/background color for clickable objects
  clickable_text_default = colors.black,
  clickable_bg_default = colors.lightGray,
  -- background colors for the states of switches
  switch_on = colors.blue,
  switch_off = colors.gray,
  -- default foreground/background colors for menu objects
  menu_text_default = colors.white,
  menu_bg_default = colors.gray,
  -- selector button colors (e.g. radiobuttons, checkboxes)
  selector_selected_fg = colors.white,
  selector_selected_bg = colors.blue,
  selector_unselected_fg = colors.black,
  selector_unselected_bg = colors.lightGray,
  -- drop shadow color
  drop_shadow = colors.gray,
  -- drop menu colors
  dropdown_text_default = colors.black,
  dropdown_bg_default = colors.lightGray,
}
