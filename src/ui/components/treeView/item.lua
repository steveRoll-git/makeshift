local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local fontCache = require "util.fontCache"

---@class TreeViewItem: Zap.ElementClass
---@field text string
---@field font love.Font?
---@field icon love.Image
---@field onClick function
---@operator call:TreeViewItem
local TreeViewItem = zap.elementClass()

function TreeViewItem:init()
  self.font = fontCache.get("Inter-Regular.ttf", 14)
end

function TreeViewItem:desiredHeight()
  return self.font:getHeight() + 8
end

function TreeViewItem:mouseClicked(button)
  if button == 1 and self.onClick() then
    self.onClick()
  end
end

function TreeViewItem:render(x, y, w, h)
  if self:isHovered() then
    lg.setColor(CurrentTheme.elementHovered)
    lg.rectangle("fill", x, y, w, h)
  end
  local textX = x + 3
  if self.icon then
    lg.setColor(CurrentTheme.foregroundActive)
    lg.draw(self.icon, x, y + h / 2 - self.icon:getHeight() / 2)
    textX = textX + self.icon:getWidth()
  end
  local font = self.font or lg.getFont()
  lg.setFont(font)
  lg.setColor(CurrentTheme.foregroundActive)
  lg.print(self.text, textX, y + h / 2 - font:getHeight() / 2)
end

return TreeViewItem
