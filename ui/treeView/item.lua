local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local fonts = require "fonts"

---@class TreeViewItem: Zap.ElementClass
---@field text string
---@field font love.Font?
---@field onClick function
---@operator call:TreeViewItem
local treeViewItem = zap.elementClass()

function treeViewItem:init()
  self.font = fonts("Inter-Regular.ttf", 14)
end

function treeViewItem:desiredHeight()
  return self.font:getHeight() + 8
end

function treeViewItem:mouseClicked(button)
  if button == 1 and self.onClick() then
    self.onClick()
  end
end

function treeViewItem:render(x, y, w, h)
  if self:isHovered() then
    lg.setColor(1, 1, 1, 0.1)
    lg.rectangle("fill", x, y, w, h)
  end
  local font = self.font or lg.getFont()
  lg.setFont(font)
  lg.setColor(1, 1, 1)
  lg.print(self.text, x + 3, y + h / 2 - font:getHeight() / 2)
end

return treeViewItem
