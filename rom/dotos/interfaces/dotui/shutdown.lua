-- shutdown prompt --

local dotos = require("dotos")
local dotui = require("dotui")

local window, base = dotui.util.basicWindow(3, 3, 24, 10, "Shutdown")

local page = dotui.UIPage:new {
  x = 2, y = 2, w = base.w - 2, h = base.h - 1,
}
base:addChild(page)

page.text = "Choose an action to perform:"
page.wrap = true

local items = {
  "Shut Down",
  "Restart"
}

local itemFunctions = {
  os.shutdown,
  os.reboot
}

local selector = dotui.Selector:new {
  x = 2, y = 4, w = page.w, h = #items,
  items = items,
  exclusive = true
}

selector.selected[1] = true

page:addChild(selector)

page:addChild( dotui.Clickable:new {
  x = page.w - 7, y = page.h - 1, w = 7, h = 1,
  text = "Confirm",
  callback = function()
    for i, func in ipairs(itemFunctions) do
      if selector.selected[i] then
        func()
      end
    end
  end
} )

dotui.util.genericWindowLoop(window)

dotos.exit()
