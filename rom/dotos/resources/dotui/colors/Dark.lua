local colors = require("colors")

-- see colors/Light for a description of these fields
return {
  textcol_default = colors.white,
  textcol_titlebar = colors.white, textcol_close = colors.black,
  
  bg_default = colors.black,
  bg_titlebar = colors.gray, bg_close = colors.red,
  
  clickable_text_default = colors.white,
  clickable_bg_default = colors.gray,

  switch_on = colors.blue,
  switck_off = colors.gray,

  menu_text_default = colors.white,
  menu_bg_default = colors.gray,

  selector_selected_fg = colors.white,
  selector_selected_bg = colors.blue,
  selector_unselected_fg = colors.lightGray,
  selector_unselected_bg = colors.gray,

  -- no drop shadow

  dropdown_text_default = colors.white,
  dropdown_bg_default = colors.gray
}
