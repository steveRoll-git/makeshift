local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"

local treeViewItem = require "ui.treeView.item"

---@class TreeItemModel
---@field text string
---@field icon love.Image?
---@field onClick function

---@class TreeView: Zap.ElementClass
---@field items TreeViewItem[]
---@operator call:TreeView
local treeView = zap.elementClass()

function treeView:init()
  self.items = {}
end

---Sets the items displayed by this TreeView.
---@param items TreeItemModel[]
function treeView:setItems(items)
  self.items = {}
  for _, itemModel in ipairs(items) do
    local item = treeViewItem()
    item.text = itemModel.text
    item.icon = itemModel.icon
    item.onClick = itemModel.onClick
    table.insert(self.items, item)
  end
end

function treeView:render(x, y, w, h)
  lg.setColor(CurrentTheme.backgroundActive)
  lg.rectangle("fill", x, y, w, h)

  local itemY = y
  for _, item in ipairs(self.items) do
    local itemH = item:desiredHeight()
    item:render(x, itemY, w, itemH)
    itemY = itemY + itemH
  end
end

return treeView
