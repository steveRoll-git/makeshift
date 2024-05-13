local love = love
local lg = love.graphics

local hexToColor = require "util.hexToColor"
local zap = require "lib.zap.zap"
local images = require "images"
local viewTools = require "util.viewTools"

local transparency = images["transparency.png"]

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

---@class ColorItem: Zap.ElementClass
---@field color number[]
---@operator call:ColorItem
local colorItem = zap.elementClass()

function colorItem:init()
  self.rectFunc = function()
    local x, y, w, h = self:getView()
    lg.rectangle("fill", x, y, w, h, 6)
  end
end

function colorItem:mousePressed()
  local spriteEditor = self:getParent():getParent() --[[@as SpriteEditor]]
  if not IsPopupOpen(spriteEditor.colorPicker) then
    spriteEditor:openColorPicker()
  else
    ClosePopup(spriteEditor.colorPicker)
  end
end

function colorItem:render(x, y, w, h)
  lg.setStencilTest("greater", 0)
  lg.stencil(self.rectFunc)
  lg.setColor(1, 1, 1)
  lg.draw(transparency, x, y, 0, w / transparency:getWidth(), h / transparency:getHeight())
  lg.setColor(self.color)
  self.rectFunc()
  lg.setLineWidth(2)
  lg.setColor(0, 0, 0, 0.2)
  lg.rectangle("line", x + 2, y + 2, w - 4, h - 4, 6)
  lg.setStencilTest()

  lg.setLineWidth(2)
  lg.setColor(1, 1, 1)
  lg.rectangle("line", x, y, w, h, 6)
end

---@class SpriteEditorToolbar: Zap.ElementClass
---@field tools Zap.Element[]
---@operator call:SpriteEditorToolbar
local toolbar = zap.elementClass()

function toolbar:init(color)
  self.pencilTool = toolbarItem()
  self.pencilTool.image = images["icons/edit_48.png"]
  self.pencilTool.toolName = "pencil"

  self.eraserTool = toolbarItem()
  self.eraserTool.image = images["icons/eraser_48.png"]
  self.eraserTool.toolName = "eraser"

  self.fillTool = toolbarItem()
  self.fillTool.image = images["icons/bucket_48.png"]
  self.fillTool.toolName = "fill"

  self.colorTool = colorItem()
  self.colorTool.color = color

  self.tools = {
    self.pencilTool,
    self.eraserTool,
    self.fillTool,
    self.colorTool
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
    local ix, iy, iw, ih = x + itemPadding, y + (i - 1) * (itemSize + itemPadding) + itemPadding, itemSize, itemSize
    if item == self.colorTool then
      ix, iy, iw, ih = viewTools.padding(ix, iy, iw, ih, 4)
    end
    item:render(ix, iy, iw, ih)
  end
end

return toolbar
