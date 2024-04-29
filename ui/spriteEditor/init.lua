local love = love
local lg = love.graphics

local hexToColor = require "util.hexToColor"
local zap = require "lib.zap.zap"
local tab = require "ui.tabView.tab"

local initialImageSize = 128

local transparency = lg.newImage("images/transparency.png")
transparency:setWrap("repeat", "repeat")

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
---@operator call:SpriteEditor
local spriteEditor = zap.elementClass()

function spriteEditor:init()
  self.panX = 0
  self.panY = 0
  self.zoom = 1
  self.currentFrameIndex = 1
  self.viewTransform = love.math.newTransform()
  self.transparencyQuad = lg.newQuad(0, 0, 128, 128, transparency:getDimensions())
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

---Returns whether `x` and `y` are inside the image's dimentions.
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
function spriteEditor:paintCircle(toX, toY, fromX, fromY, color)
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

  self.clean = false
end

function spriteEditor:mousePressed(button)
  if button == 3 then
    self.panning = true
    local mx, my = self:getAbsoluteMouse()
    self.panStart = {
      x = self.panX - mx,
      y = self.panY - my,
    }
  end
end

function spriteEditor:mouseReleased(button)
  if button == 3 then
    self.panning = false
  end
end

function spriteEditor:mouseMoved(x, y)
  if self.panning then
    self.panX = x + self.panStart.x
    self.panY = y + self.panStart.y
  end
end

function spriteEditor:render(x, y, w, h)
  self:updateViewTransform()

  lg.setScissor(x, y, w, h)
  lg.push()
  lg.translate(x, y)

  -- local ox, oy = self.viewTransform:transformPoint(0, 0)
  -- lg.setColor(1, 1, 1)
  -- lg.circle("fill", ox, oy, 3)
  -- lg.setColor(0, 0, 0)
  -- lg.setLineStyle("smooth")
  -- lg.setLineWidth(1)
  -- lg.circle("line", ox, oy, 3)

  local tx, ty = self.viewTransform:transformPoint(0, 0)
  lg.setColor(1, 1, 1)
  lg.draw(transparency, self.transparencyQuad, tx, ty)

  lg.applyTransform(self.viewTransform)
  lg.draw(self:currentFrame().image)

  lg.pop()
  lg.setScissor()
end

return spriteEditor
