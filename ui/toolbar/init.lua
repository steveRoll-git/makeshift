local love = love
local lg = love.graphics

local hexToColor = require "util.hexToColor"
local zap = require "lib.zap.zap"
local button = require "ui.button"
local fonts = require "fonts"

---@class Toolbar: Zap.ElementClass
---@field private buttons Zap.Element[]
---@operator call:Toolbar
local toolbar = zap.elementClass()

---Sets this toolbar's items.
---@param items {image: love.Image, text: string, action: fun()}[]
function toolbar:setItems(items)
  self.buttons = {}
  for _, item in ipairs(items) do
    local b = button()
    b.image = item.image
    b.text = item.text
    b.onClick = item.action
    b.displayMode = "textAfterImage"
    b.font = fonts("Inter-Regular.ttf", 14)
    b.textImageMargin = 3
    table.insert(self.buttons, b)
  end
end

function toolbar:desiredHeight()
  return 34
end

function toolbar:render(x, y, w, h)
  lg.setColor(hexToColor(0x181818))
  lg.rectangle("fill", x, y, w, h)

  local itemX = x
  for _, b in ipairs(self.buttons) do
    local buttonW = b:desiredWidth() + 12
    b:render(itemX, y, buttonW, h)
    itemX = itemX + buttonW
  end
end

return toolbar
