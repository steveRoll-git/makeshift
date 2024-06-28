local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"

local TreeViewItem = require "ui.components.treeView.item"

---@class TreeView.ItemModel
---@field text string
---@field icon love.Image?
---@field onClick? fun(self: TreeView.Item)
---@field onRightClick? fun(self: TreeView.Item)
---@field onRename? fun(self: TreeView.Item, name: string)

---@class TreeView: Zap.ElementClass
---@field items TreeView.Item[]
---@operator call:TreeView
local TreeView = zap.elementClass()

function TreeView:init()
  self.items = {}
end

---Sets the items displayed by this TreeView.
---@param items TreeView.ItemModel[]
function TreeView:setItems(items)
  self.items = {}
  for _, itemModel in ipairs(items) do
    local item = TreeViewItem()
    item.text = itemModel.text
    item.icon = itemModel.icon
    item.onClick = itemModel.onClick
    item.onRightClick = itemModel.onRightClick
    item.onRename = itemModel.onRename
    table.insert(self.items, item)
  end
end

function TreeView:render(x, y, w, h)
  lg.setColor(CurrentTheme.backgroundActive)
  lg.rectangle("fill", x, y, w, h)

  local itemY = y
  for _, item in ipairs(self.items) do
    local itemH = item:desiredHeight()
    item:render(x, itemY, w, itemH)
    itemY = itemY + itemH
  end
end

return TreeView
