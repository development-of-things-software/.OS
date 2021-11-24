-- rough signal type classifications --

local types = {}

types.mouse = {
  mouse_scroll = true,
  mouse_click = true,
  mouse_drag = true,
  mouse_up = true,
}

types.keyboard = {
  clipboard = true,
  key_up = true,
  key = true,
}

return types
