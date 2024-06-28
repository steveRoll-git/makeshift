local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local fontCache = require "util.fontCache"
local TempEditor = require "ui.components.tempEditor"

---@class TreeView.Item: Zap.ElementClass
---@field text string
---@field font love.Font
---@field icon love.Image
---@field data any
---@field onClick fun(self: TreeView.Item)
---@field onRightClick fun(self: TreeView.Item)
---@field onRename fun(self: TreeView.Item, name: string)
---@field onRenameCancel fun(self: TreeView.Item)
---@operator call:TreeView.Item
local TreeViewItem = zap.elementClass()

function TreeViewItem:init()
  self.font = fontCache.get("Inter-Regular.ttf", 14)
end

function TreeViewItem:startRename()
  local tempEditor = TempEditor(self.text)
  tempEditor:setFont(self.font)
  tempEditor.writeValue = function(value)
    if #value == 0 then
      self:onRenameCancel()
      return
    end
    self.text = value
    self:onRename(value)
  end
  tempEditor.onCancel = function()
    self:onRenameCancel()
  end
  OpenPopup(tempEditor, self:getTextView())
end

function TreeViewItem:getTextView()
  local x, y, w, h = self:getView()
  local newW = w - 3
  if self.icon then
    newW = newW - self.icon:getWidth()
  end
  return x + (w - newW), y, newW, h
end

function TreeViewItem:desiredHeight()
  return self.font:getHeight() + 8
end

function TreeViewItem:mouseClicked(button)
  if button == 1 and self.onClick then
    self:onClick()
  elseif button == 2 and self.onRightClick then
    self:onRightClick()
  end
end

function TreeViewItem:render(x, y, w, h)
  if self:isHovered() then
    lg.setColor(CurrentTheme.elementHovered)
    lg.rectangle("fill", x, y, w, h)
  end
  if self.icon then
    lg.setColor(CurrentTheme.foregroundActive)
    lg.draw(self.icon, x, y + h / 2 - self.icon:getHeight() / 2)
  end
  local textX, textY, _, _ = self:getTextView()
  lg.setFont(self.font)
  lg.setColor(CurrentTheme.foregroundActive)
  lg.print(self.text, textX, math.floor(textY + h / 2 - self.font:getHeight() / 2))
end

return TreeViewItem
