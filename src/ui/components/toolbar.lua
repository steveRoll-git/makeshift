local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local button = require "ui.components.button"
local fontCache = require "util.fontCache"
local viewTools = require "util.viewTools"

---@class Toolbar: Zap.ElementClass
---@field private buttons Zap.Element[]
---@operator call:Toolbar
local toolbar = zap.elementClass()

---Sets this toolbar's items.
---@param items {image: love.Image, text: string, action: fun(), visible?: boolean | fun(): boolean}[]
function toolbar:setItems(items)
  self.models = items
  self.buttons = {}
  for _, item in ipairs(items) do
    local b = button()
    b.image = item.image
    b.text = item.text
    b.onClick = item.action
    b.displayMode = "textAfterImage"
    b.font = fontCache.get("Inter-Regular.ttf", 14)
    b.textImageMargin = 6
    table.insert(self.buttons, b)
  end
end

function toolbar:desiredHeight()
  return 34
end

function toolbar:render(x, y, w, h)
  lg.setColor(CurrentTheme.backgroundActive)
  lg.rectangle("fill", x, y, w, h)

  local itemX = x
  for i, b in ipairs(self.buttons) do
    local model = self.models[i]
    local visible
    if type(model.visible) == "function" then
      visible = model.visible()
    else
      visible = model.visible or type(model.visible) == "nil"
    end
    if visible then
      local buttonW = b:desiredWidth() + 12
      b:render(viewTools.padding(itemX, y, buttonW, h, 1))
      itemX = itemX + buttonW
    end
  end

  lg.setColor(CurrentTheme.outline)
  lg.setLineStyle("rough")
  lg.setLineWidth(1)
  lg.line(x, y + h, x + w, y + h)
end

return toolbar
