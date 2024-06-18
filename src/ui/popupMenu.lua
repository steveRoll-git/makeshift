local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local fonts = require "fonts"
local button = require "ui.button"

local itemPadding = 3
local itemTextPadding = 3

local font = fonts("Inter-Regular.ttf", 14)
local itemHeight = font:getHeight() + itemTextPadding * 2

---@class PopupMenuItemModel
---@field text string
---@field action function
---@field visible? boolean | fun(): boolean

---@class PopupMenu: Zap.ElementClass
---@field items Zap.Element[]
---@field separators table<number, boolean>
---@operator call:PopupMenu
local popupMenu = zap.elementClass()

---Sets the items inside this PopupMenu.
---@param items (PopupMenuItemModel | "separator")[]
function popupMenu:setItems(items)
  self.models = items
  self.items = {}
  self.separators = {}
  for _, item in ipairs(items) do
    if type(item) == "table" then
      local newButton = button()
      newButton.displayMode = "text"
      newButton.text = item.text
      newButton.font = font
      newButton.alignText = "left"
      newButton.textPadding = itemTextPadding
      newButton.onClick = function()
        item.action()
        ClosePopup(self)
      end
      table.insert(self.items, newButton)
    elseif item == "separator" then
      self.separators[#self.items] = true
    end
  end
end

---Returns whether the item at `index` is visible.
---@param index number
---@return boolean
function popupMenu:isItemVisible(index)
  local model = self.models[index]
  if type(model.visible) == "function" then
    return model.visible()
  else
    local visible = model.visible --[[@as boolean?]]
    return visible or type(visible) == "nil"
  end
end

function popupMenu:desiredWidth()
  return 200
end

function popupMenu:desiredHeight()
  local h = itemPadding * 2
  for i, _ in ipairs(self.items) do
    if self:isItemVisible(i) then
      h = h + itemHeight
    end
  end
  for _, _ in pairs(self.separators) do
    h = h + itemPadding * 2
  end
  return h
end

---Opens this menu as a popup at the cursor's position.
function popupMenu:popupAtCursor()
  local mx, my = love.mouse.getPosition()
  OpenPopup(self, mx, my, self:desiredWidth(), self:desiredHeight())
end

function popupMenu:render(x, y, w, h)
  lg.setColor(CurrentTheme.backgroundActive)
  lg.rectangle("fill", x, y, w, h, 6)
  lg.setColor(CurrentTheme.outlineActive)
  lg.setLineStyle("rough")
  lg.setLineWidth(1)
  lg.rectangle("line", x, y, w, h, 6)

  local itemY = y + itemPadding
  for i, item in ipairs(self.items) do
    if self:isItemVisible(i) then
      item:render(x + itemPadding, itemY, w - itemPadding * 2, itemHeight)
      itemY = itemY + itemHeight
      if self.separators[i] then
        itemY = itemY + itemPadding
        lg.setColor(CurrentTheme.outlineActive)
        lg.setLineStyle("rough")
        lg.setLineWidth(1)
        lg.line(x, itemY, x + w, itemY)
        itemY = itemY + itemPadding
      end
    end
  end
end

return popupMenu
