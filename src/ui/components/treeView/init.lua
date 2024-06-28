local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local OrderedSet = require "util.orderedSet"

local TreeViewItem = require "ui.components.treeView.item"

---@class TreeView.ItemModel
---@field text string
---@field icon love.Image?
---@field data any
---@field onClick? fun(self: TreeView.Item)
---@field onRightClick? fun(self: TreeView.Item)
---@field onRename? fun(self: TreeView.Item, name: string)
---@field onRenameCancel? fun(self: TreeView.Item)

---@class TreeView: Zap.ElementClass
---@field items OrderedSet
---@operator call:TreeView
local TreeView = zap.elementClass()

function TreeView:init()
  self.items = OrderedSet.new()
end

---Appends a new item.
---@param model TreeView.ItemModel
---@param temporary? boolean If true, this item will start being renamed immediately, and removed after pressing enter or escape.
function TreeView:addItem(model, temporary)
  local item = TreeViewItem()
  item.text = model.text
  item.icon = model.icon
  item.data = model.data
  item.onClick = model.onClick
  item.onRightClick = model.onRightClick
  item.onRename = model.onRename
  item.onRenameCancel = model.onRenameCancel
  if temporary then
    item.onRename = function(_, name)
      self.items:remove(item)
      if model.onRename then
        model.onRename(item, name)
      end
    end
    item.onRenameCancel = function(_)
      self.items:remove(item)
      if model.onRenameCancel then
        model.onRenameCancel(item)
      end
    end
    item:nextRender(function(e)
      item:startRename()
    end)
  end
  self.items:add(item)
end

---Sets the items displayed by this TreeView.
---@param items TreeView.ItemModel[]
function TreeView:setItems(items)
  self.items = OrderedSet.new()
  for _, model in ipairs(items) do
    self:addItem(model)
  end
end

function TreeView:render(x, y, w, h)
  lg.setColor(CurrentTheme.backgroundActive)
  lg.rectangle("fill", x, y, w, h)

  local itemY = y
  for _, item in ipairs(self.items.list) do
    local itemH = item:desiredHeight()
    item:render(x, itemY, w, itemH)
    itemY = itemY + itemH
  end
end

return TreeView
