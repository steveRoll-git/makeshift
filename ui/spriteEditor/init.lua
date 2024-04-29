local love = love
local lg = love.graphics

local hexToColor = require "util.hexToColor"
local compareColors = require "util.compareColors"
local dist = require "util.dist"
local zap = require "lib.zap.zap"
local tab = require "ui.tabView.tab"
local toolbar = require "ui.spriteEditor.toolbar"
local images = require "images"

local initialImageSize = 128

local transparentColor = { 0, 0, 0, 0 }

local transparency = images["transparency.png"]
transparency:setWrap("repeat", "repeat")

---@alias ToolType "pencil" | "eraser" | "fill"

---@class SpriteEditor: Zap.ElementClass
---@field editingObject Object
---@field currentFrameIndex number
---@field panX number
---@field panY number
---@field zoom number
---@field panning boolean
---@field panStart {x: number, y: number}?
---@field viewTransform love.Transform
---@field transparencyQuad love.Quad
---@field currentToolType ToolType
---@field toolSize number
---@field currentColor number[]
---@operator call:SpriteEditor
local spriteEditor = zap.elementClass()

function spriteEditor:init()
  self.panX = 0
  self.panY = 0
  self.zoom = 1
  self.currentFrameIndex = 1
  self.viewTransform = love.math.newTransform()
  self.transparencyQuad = lg.newQuad(0, 0, 128, 128, transparency:getDimensions())

  self.toolbar = toolbar()

  self.tools = {
    pencil = {
      onDrag = function(fromX, fromY, toX, toY)
        self:paintCircle(fromX, fromY, toX, toY, self.currentColor)
      end
    },
    eraser = {
      onDrag = function(fromX, fromY, toX, toY)
        self:paintCircle(fromX, fromY, toX, toY, transparentColor)
      end
    },
    fill = {
      onPress = function(x, y)
        self:floodFill(x, y, self.currentColor)
      end
    }
  }
  self.currentToolType = "pencil"
  self.toolSize = 1
  self.currentColor = { 1, 1, 1, 1 }
end

---Updates `viewTransform` according to the current values of `panX`, `panY` and `zoom`.
function spriteEditor:updateViewTransform()
  local _, _, w, h = self:getView()
  self.viewTransform:reset():setTransformation(
    math.floor(self.panX),
    math.floor(self.panY),
    0,
    self.zoom,
    self.zoom,
    math.floor(-w / 2),
    math.floor(-h / 2))
end

---Updates `transparencyQuad`'s viewport to fit the size of the image.
function spriteEditor:updateTransparencyQuad()
  self.transparencyQuad:setViewport(0, 0,
    self:currentImageData():getWidth() * self.zoom,
    self:currentImageData():getHeight() * self.zoom,
    transparency:getDimensions())
end

---Returns the frame currently being edited.
---@return SpriteFrame
function spriteEditor:currentFrame()
  return self.editingObject.frames[self.currentFrameIndex]
end

---Returns the ImageData currently being edited.
---@return love.ImageData
function spriteEditor:currentImageData()
  return self:currentFrame().imageData
end

---Returns the currently active tool.
---@return table
function spriteEditor:currentTool()
  return self.tools[self.currentToolType]
end

---Returns the position of the mouse in image coordinates.
---@return number x
---@return number y
function spriteEditor:mouseImageCoords()
  local mx, my = self:getRelativeMouse()
  local ix, iy = self.viewTransform:inverseTransformPoint(mx, my)
  return ix, iy
end

---Appends a new frame to the edited object. If `width` and `height` are not given, the size will be the same as the object's last frame.
---@param width number?
---@param height number?
function spriteEditor:addFrame(width, height)
  if not width then
    width, height = self.editingObject.frames[#self.editingObject.frames].imageData:getDimensions()
  end
  ---@cast width number
  ---@cast height number
  local frame = {
    imageData = love.image.newImageData(width, height)
  }
  frame.image = lg.newImage(frame.imageData)
  table.insert(self.editingObject.frames, frame)
  self.currentFrameIndex = #self.editingObject.frames
  self.panX = -width / 2
  self.panY = -height / 2
  self:updateTransparencyQuad()
end

---Returns whether `x` and `y` are inside the image's dimensions.
---@param x number
---@param y number
---@return boolean
function spriteEditor:inRange(x, y)
  return x >= 0 and x < self:currentImageData():getWidth() and y >= 0 and y < self:currentImageData():getHeight()
end

---Sets a pixel in the currently edited imageData.
---@param x number
---@param y number
---@param color number[]
function spriteEditor:setPixel(x, y, color)
  if self:inRange(x, y) then
    self:currentImageData():setPixel(x, y, color)
  end
end

---Updates the displayed image of the current frame to the contents of the ImageData.
function spriteEditor:updateImage()
  self:currentFrame().image:replacePixels(self:currentImageData())
end

---Fills an ellipse in the image.
---Algorithm from http://members.chello.at/easyfilter/bresenham.html
---@param x0 number
---@param y0 number
---@param x1 number
---@param y1 number
---@param color number[]
function spriteEditor:fillEllipse(x0, y0, x1, y1, color)
  if (x0 == x1 and y0 == y1) then
    self:setPixel(x0, y0, color)
    return
  end
  local a = math.abs(x1 - x0)
  local b = math.abs(y1 - y0)
  local b1 = b % 2
  local dx = 4 * (1 - a) * b * b
  local dy = 4 * (b1 + 1) * a * a
  local err = dx + dy + b1 * a * a
  local e2

  if (x0 > x1) then
    x0 = x1
    x1 = x1 + a
  end
  if (y0 > y1) then
    y0 = y1
  end
  y0 = y0 + (b + 1) / 2
  y1 = y0 - b1
  a = a * 8 * a
  b1 = 8 * b * b

  repeat
    for x = x0, x1 do
      self:setPixel(x, y0, color)
      self:setPixel(x, y1, color)
    end
    e2 = 2 * err
    if (e2 <= dy) then
      y0 = y0 + 1
      y1 = y1 - 1
      dy = dy + a
      err = err + dy
    end
    if (e2 >= dx or 2 * err > dy) then
      x0 = x0 + 1
      x1 = x1 - 1
      dx = dx + b1
      err = err + dx
    end
  until (x0 > x1)

  while (y0 - y1 < b) do
    self:setPixel(x0 - 1, y0, color)
    self:setPixel(x1 + 1, y0, color)
    y0 = y0 + 1
    self:setPixel(x0 - 1, y1, color)
    self:setPixel(x1 + 1, y1, color)
    y1 = y1 - 1
  end
end

---Paints a stroke from one position to another.
---@param toX number
---@param toY number
---@param fromX number
---@param fromY number
---@param color number[]
function spriteEditor:paintCircle(fromX, fromY, toX, toY, color)
  local size = self.toolSize

  local currentX, currentY = fromX, fromY

  local dirX, dirY = toX - fromX, toY - fromY
  local step = math.abs(dirX) > math.abs(dirY) and math.abs(dirX) or math.abs(dirY)
  local nextX, nextY = currentX, currentY

  local count = 0

  repeat
    currentX = nextX
    currentY = nextY
    local x = currentX + 0.5
    local y = currentY + 0.5
    local x1, y1 = x - size / 2, y - size / 2
    local x2, y2 = x + size / 2 - 1, y + size / 2 - 1
    self:fillEllipse(x1, y1, x2, y2, color)
    nextX, nextY = currentX + dirX / step, currentY + dirY / step
    count = count + 1
  until dist(currentX, currentY, toX, toY) <= 0.5
end

---Scanline flood fill algorithm, adapted from:
---https://lodev.org/cgtutor/floodfill.html
---@param origX number
---@param origY number
---@param newColor number[]
function spriteEditor:floodFill(origX, origY, newColor)
  local imageData = self:currentImageData()

  local oldColor = { imageData:getPixel(origX, origY) }

  if compareColors(oldColor, newColor) then
    return
  end

  local stack = {}
  table.insert(stack, origX)
  table.insert(stack, origY)

  while #stack > 0 do
    local y = table.remove(stack)
    local x = table.remove(stack)
    local spanAbove = false
    local spanBelow = false
    local x1 = x
    while x1 >= 0 and compareColors(oldColor, imageData:getPixel(x1, y)) do
      x1 = x1 - 1
    end
    x1 = x1 + 1
    while x1 < imageData:getWidth() and compareColors(oldColor, imageData:getPixel(x1, y)) do
      imageData:setPixel(x1, y, newColor)
      if not spanAbove and y > 0 and compareColors(oldColor, imageData:getPixel(x1, y - 1)) then
        table.insert(stack, x1)
        table.insert(stack, y - 1)
        spanAbove = true
      elseif spanAbove and y > 0 and not compareColors(oldColor, imageData:getPixel(x1, y - 1)) then
        spanAbove = false
      end
      if not spanBelow and y < imageData:getHeight() - 1 and
          compareColors(oldColor, imageData:getPixel(x1, y + 1)) then
        table.insert(stack, x1)
        table.insert(stack, y + 1)
        spanBelow = true
      elseif spanBelow and y < imageData:getHeight() - 1 and
          not compareColors(oldColor, imageData:getPixel(x1, y + 1)) then
        spanBelow = false
      end
      x1 = x1 + 1
    end
  end
end

function spriteEditor:mousePressed(button)
  if button == 1 then
    local ix, iy = self:mouseImageCoords()
    local tool = self:currentTool()
    if tool.onDrag then
      tool.onDrag(ix, iy, ix, iy)
      self:updateImage()
      self.dragDrawing = true
      self.prevToolX = ix
      self.prevToolY = iy
    elseif tool.onPress and self:inRange(ix, iy) then
      tool.onPress(ix, iy)
      self:updateImage()
    end
  elseif button == 3 then
    self.panning = true
    local mx, my = self:getAbsoluteMouse()
    self.panStart = {
      x = self.panX - mx,
      y = self.panY - my,
    }
  end
end

function spriteEditor:mouseReleased(button)
  if button == 1 then
    self.dragDrawing = false
  elseif button == 3 then
    self.panning = false
  end
end

function spriteEditor:mouseMoved(x, y)
  if self.dragDrawing then
    local ix, iy = self:mouseImageCoords()
    self:currentTool().onDrag(self.prevToolX, self.prevToolY, ix, iy)
    self:updateImage()
    self.prevToolX = ix
    self.prevToolY = iy
  elseif self.panning then
    self.panX = x + self.panStart.x
    self.panY = y + self.panStart.y
  end
end

function spriteEditor:render(x, y, w, h)
  self:updateViewTransform()

  lg.setScissor(x, y, w, h)
  lg.push()
  lg.translate(x, y)

  local tx, ty = self.viewTransform:transformPoint(0, 0)
  lg.setColor(1, 1, 1)
  lg.draw(transparency, self.transparencyQuad, tx, ty)

  lg.applyTransform(self.viewTransform)
  lg.draw(self:currentFrame().image)

  lg.pop()

  self.toolbar:render(x, y + h / 2 - self.toolbar:desiredHeight() / 2,
    self.toolbar:desiredWidth(), self.toolbar:desiredHeight())

  lg.setScissor()
end

return spriteEditor
