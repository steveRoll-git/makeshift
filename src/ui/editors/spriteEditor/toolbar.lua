local love = love
local lg = love.graphics

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
local ToolbarItem = zap.elementClass()

function ToolbarItem:mousePressed(btn)
  self:spriteEditor().currentToolType = self.toolName
end

---Gets the parent SpriteEditor.
---@return SpriteEditor
function ToolbarItem:spriteEditor()
  return self:getParent():getParent() --[[@as SpriteEditor]]
end

function ToolbarItem:render(x, y, w, h)
  local active = self:spriteEditor().currentToolType == self.toolName
  if active then
    lg.setColor(CurrentTheme.elementPressed)
  elseif self:isHovered() then
    lg.setColor(CurrentTheme.elementHovered)
  else
    lg.setColor(0, 0, 0, 0) -- unstyled
  end
  lg.rectangle("fill", x, y, w, h, 6)
  lg.setColor(active and CurrentTheme.foregroundActive or CurrentTheme.foreground)
  lg.draw(self.image, x, y)
end

---@class ColorItem: Zap.ElementClass
---@field color number[]
---@operator call:ColorItem
local ColorItem = zap.elementClass()

function ColorItem:init()
  self.rectFunc = function()
    local x, y, w, h = self:getView()
    lg.rectangle("fill", x, y, w, h, 6)
  end
end

function ColorItem:mousePressed()
  local spriteEditor = self:getParent():getParent() --[[@as SpriteEditor]]
  if not IsPopupOpen(spriteEditor.colorPicker) then
    spriteEditor:openColorPicker()
  else
    ClosePopup(spriteEditor.colorPicker)
  end
end

function ColorItem:render(x, y, w, h)
  lg.setStencilTest("greater", 0)
  lg.stencil(self.rectFunc)
  lg.setColor(1, 1, 1) -- unstyled
  lg.draw(transparency, x, y, 0, w / transparency:getWidth(), h / transparency:getHeight())
  lg.setColor(self.color)
  self.rectFunc()
  lg.setLineWidth(2)
  lg.setColor(0, 0, 0, 0.2) -- unstyled
  lg.rectangle("line", x + 2, y + 2, w - 4, h - 4, 6)
  lg.setStencilTest()

  lg.setLineWidth(2)
  lg.setColor(1, 1, 1) -- unstyled
  lg.rectangle("line", x, y, w, h, 6)
end

---@class SpriteEditor.Toolbar: Zap.ElementClass
---@field tools Zap.Element[]
---@operator call:SpriteEditor.Toolbar
local Toolbar = zap.elementClass()

function Toolbar:init(color)
  self.pencilTool = ToolbarItem()
  self.pencilTool.image = images["icons/edit_48.png"]
  self.pencilTool.toolName = "pencil"

  self.eraserTool = ToolbarItem()
  self.eraserTool.image = images["icons/eraser_48.png"]
  self.eraserTool.toolName = "eraser"

  self.fillTool = ToolbarItem()
  self.fillTool.image = images["icons/bucket_48.png"]
  self.fillTool.toolName = "fill"

  self.colorTool = ColorItem()
  self.colorTool.color = color

  self.tools = {
    self.pencilTool,
    self.eraserTool,
    self.fillTool,
    self.colorTool
  }
end

function Toolbar:desiredWidth()
  return itemSize + itemPadding * 2
end

function Toolbar:desiredHeight()
  return #self.tools * (itemSize + itemPadding) + itemPadding
end

function Toolbar:render(x, y, w, h)
  lg.setColor(CurrentTheme.backgroundActive)
  lg.rectangle("fill", x - 6, y, w + 6, h, 6)
  for i, item in ipairs(self.tools) do
    local ix, iy, iw, ih = x + itemPadding, y + (i - 1) * (itemSize + itemPadding) + itemPadding, itemSize, itemSize
    if item == self.colorTool then
      ix, iy, iw, ih = viewTools.padding(ix, iy, iw, ih, 4)
    end
    item:render(ix, iy, iw, ih)
  end
end

return Toolbar
