local love = love
local lg = love.graphics

local hexToColor = require "util.hexToColor"
local zap = require "lib.zap.zap"
local images = require "images"

local itemSize = 48
local itemPadding = 6

---@class SpriteEditorToolbarItem: Zap.ElementClass
---@field image love.Image
---@field toolName ToolType
---@operator call:SpriteEditorToolbarItem
local toolbarItem = zap.elementClass()

function toolbarItem:mousePressed(btn)
  self:spriteEditor().currentToolType = self.toolName
end

---Gets the parent SpriteEditor.
---@return SpriteEditor
function toolbarItem:spriteEditor()
  return self:getParent():getParent() --[[@as SpriteEditor]]
end

function toolbarItem:render(x, y, w, h)
  if self:spriteEditor().currentToolType == self.toolName then
    lg.setColor(1, 1, 1, 0.2)
  elseif self:isHovered() then
    lg.setColor(1, 1, 1, 0.08)
  else
    lg.setColor(0, 0, 0, 0)
  end
  lg.rectangle("fill", x, y, w, h, 6)
  lg.setColor(hexToColor(0xcccccc))
  lg.draw(self.image, x, y)
end

---@class SpriteEditorToolbar: Zap.ElementClass
---@field tools SpriteEditorToolbarItem[]
---@operator call:SpriteEditorToolbar
local toolbar = zap.elementClass()

function toolbar:init()
  local pencilTool = toolbarItem()
  pencilTool.image = images["icons/edit_48.png"]
  pencilTool.toolName = "pencil"

  local eraserTool = toolbarItem()
  eraserTool.image = images["icons/eraser_48.png"]
  eraserTool.toolName = "eraser"

  local fillTool = toolbarItem()
  fillTool.image = images["icons/bucket_48.png"]
  fillTool.toolName = "fill"

  self.tools = {
    pencilTool,
    eraserTool,
    fillTool
  }
end

function toolbar:desiredWidth()
  return itemSize + itemPadding * 2
end

function toolbar:desiredHeight()
  return #self.tools * (itemSize + itemPadding) + itemPadding
end

function toolbar:render(x, y, w, h)
  lg.setColor(hexToColor(0x1f1f1f))
  lg.rectangle("fill", x - 6, y, w + 6, h, 6)
  for i, item in ipairs(self.tools) do
    item:render(x + itemPadding, y + (i - 1) * (itemSize + itemPadding) + itemPadding, itemSize, itemSize)
  end
end

return toolbar
