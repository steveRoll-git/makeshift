local love = love
local lg = love.graphics

local hexToColor = require "util.hexToColor"
local compareColors = require "util.compareColors"
local dist = require "util.dist"
local zap = require "lib.zap.zap"
local tab = require "ui.tabView.tab"
local toolbar = require "ui.spriteEditor.toolbar"
local images = require "images"
local colorPicker = require "ui.colorPicker"
local sign = require "util.sign"
local topToolbar = require "ui.toolbar"

local initialImageSize = 128

local transparentColor = { 0, 0, 0, 0 }

local zoomValues = { 0.25, 1 / 3, 0.5, 1, 2, 3, 4, 5, 6, 8, 12, 16, 24, 32, 48, 64 }

local transparency = images["transparency.png"]
transparency:setWrap("repeat", "repeat")

local clearMap = function()
  return 0, 0, 0, 0
end

local stencilShader = lg.newShader [[
  vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    if (Texel(texture, texture_coords).a == 0) {
      discard;
    }
    return vec4(1.0);
  }
]]

---Sets the imageData's pixel only if x and y are in range.
---@param imageData love.ImageData
---@param x number
---@param y number
---@param color number[]
local function safeSetPixel(imageData, x, y, color)
  if x >= 0 and x < imageData:getWidth() and y >= 0 and y < imageData:getHeight() then
    imageData:setPixel(x, y, color)
  end
end

---Fills an ellipse in the image.
---Algorithm from http://members.chello.at/easyfilter/bresenham.html
---@param imageData love.ImageData
---@param x0 number
---@param y0 number
---@param x1 number
---@param y1 number
---@param color number[]
local function fillEllipse(imageData, x0, y0, x1, y1, color)
  if (x0 == x1 and y0 == y1) then
    safeSetPixel(imageData, x0, y0, color)
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
      safeSetPixel(imageData, x, y0, color)
      safeSetPixel(imageData, x, y1, color)
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
    safeSetPixel(imageData, x0 - 1, y0, color)
    safeSetPixel(imageData, x1 + 1, y0, color)
    y0 = y0 + 1
    safeSetPixel(imageData, x0 - 1, y1, color)
    safeSetPixel(imageData, x1 + 1, y1, color)
    y1 = y1 - 1
  end
end

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
---@field embedded boolean Whether this spriteEditor is embedded in a sceneEditor.
---@operator call:SpriteEditor
local spriteEditor = zap.elementClass()

---@param sceneView SceneView
function spriteEditor:init(sceneView)
  self.panX = 0
  self.panY = 0
  self.zoom = 1
  self.currentFrameIndex = 1
  self.viewTransform = love.math.newTransform()
  self.transparencyQuad = lg.newQuad(0, 0, 128, 128, transparency:getDimensions())

  self.currentColor = { 1, 1, 1, 1 }

  self.toolbar = toolbar(self.currentColor)

  self.colorPicker = colorPicker(self.currentColor)

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

  self.embedded = not not sceneView
  local topToolbarItems = {
    {
      text = "Back",
      image = images["icons/arrow_back_24.png"],
      action = function()
        sceneView:exitSpriteEditor()
      end
    },
    {
      text = "Pop Out",
      image = images["icons/open_in_new_24.png"],
      action = function()

      end
    },
    {
      text = "Brush Size",
      image = images["icons/line_weight_24.png"],
      action = function()
      end
    }
  }
  self.topToolbar = topToolbar()
  self.topToolbar:setItems(topToolbarItems)

  self.brushPreviewData = love.image.newImageData(128, 128)
  self.brushPreview = love.graphics.newImage(self.brushPreviewData)
  self.brushPreview:setFilter("linear", "nearest")
  self:updateBrushPreview()

  self.brushOutlineStencil = function()
    local ix, iy = self:mouseImageCoords()
    lg.setShader(stencilShader)
    lg.draw(self.brushPreview, ix - math.floor(self.toolSize / 2), iy - math.floor(self.toolSize / 2))
    lg.setShader()
  end
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
    0,
    0)
end

---Updates `transparencyQuad`'s viewport to fit the size of the image.
function spriteEditor:updateTransparencyQuad()
  self.transparencyQuad:setViewport(0, 0,
    self:currentImageData():getWidth() * self.zoom,
    self:currentImageData():getHeight() * self.zoom,
    transparency:getDimensions())
end

---Updates the brush preview to match the current size.
function spriteEditor:updateBrushPreview()
  self.brushPreviewData:mapPixel(clearMap)
  fillEllipse(self.brushPreviewData, 0, 0, self.toolSize - 1, self.toolSize - 1, { 1, 1, 1, 1 })
  self.brushPreview:replacePixels(self.brushPreviewData)
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
  return math.floor(ix), math.floor(iy)
end

---Appends a new frame to the edited object.
function spriteEditor:addFrame()
  local frame = {
    imageData = love.image.newImageData(self.editingObject.w, self.editingObject.h)
  }
  frame.image = lg.newImage(frame.imageData)
  frame.image:setFilter("linear", "nearest")
  table.insert(self.editingObject.frames, frame)

  self.currentFrameIndex = #self.editingObject.frames
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
    fillEllipse(self:currentImageData(), x1, y1, x2, y2, color)
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

function spriteEditor:openColorPicker()
  local pickerWidth = 200
  local pickerHeight = 80
  local ix, iy, iw, ih = self.toolbar.colorTool:getView()
  OpenPopup(self.colorPicker,
    ix + iw + 12,
    iy + ih / 2 - pickerHeight / 2,
    pickerWidth,
    pickerHeight)
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

function spriteEditor:wheelMoved(x, y)
  if love.keyboard.isDown("lctrl", "rctrl") then
    -- change brush size
    self.toolSize = math.min(math.max(self.toolSize + sign(y), 1), 100)
    self:updateBrushPreview()
  else
    -- zoom
    local newZoom = self.zoom
    if y > 0 then
      for i = 1, #zoomValues do
        if zoomValues[i] > self.zoom then
          newZoom = zoomValues[i]
          break
        end
      end
    elseif y < 0 then
      for i = #zoomValues, 1, -1 do
        if zoomValues[i] < self.zoom then
          newZoom = zoomValues[i]
          break
        end
      end
    end
    if newZoom ~= self.zoom then
      local mx, my = self:getRelativeMouse()

      local placeX = (mx - self.panX) / (self:currentImageData():getWidth() * self.zoom)
      local placeY = (my - self.panY) / (self:currentImageData():getHeight() * self.zoom)

      self.zoom = newZoom
      self:updateViewTransform()

      self.panX = -(self:currentImageData():getWidth() * self.zoom * placeX) + mx
      self.panY = -(self:currentImageData():getHeight() * self.zoom * placeY) + my

      self:updateTransparencyQuad()
    end
  end
end

function spriteEditor:render(x, y, w, h)
  self:updateViewTransform()

  if not self.embedded then
    self.topToolbar:render(x, y, w, topToolbar:desiredHeight())
    y = y + self.topToolbar:desiredHeight()
    h = h - self.topToolbar:desiredHeight()
  end

  lg.setScissor(x, y, w, h)
  lg.push()
  lg.translate(x, y)

  local tx, ty = self.viewTransform:transformPoint(0, 0)
  lg.setColor(1, 1, 1)
  lg.draw(transparency, self.transparencyQuad, tx, ty)

  lg.applyTransform(self.viewTransform)
  lg.draw(self:currentFrame().image)

  local ix, iy = self:mouseImageCoords()
  if self.currentToolType == "pencil" then
    lg.setColor(self.currentColor)
    lg.draw(self.brushPreview, ix - math.floor(self.toolSize / 2), iy - math.floor(self.toolSize / 2))
  elseif self.currentToolType == "eraser" then
    if self.zoom > 1 then
      lg.push()
      lg.translate(1 / self.zoom, 0)
      lg.stencil(self.brushOutlineStencil, "increment", 1, true)
      lg.translate(0, 1 / self.zoom)
      lg.stencil(self.brushOutlineStencil, "increment", 1, true)
      lg.translate(-1 / self.zoom, 0)
      lg.stencil(self.brushOutlineStencil, "increment", 1, true)
      lg.translate(0, -1 / self.zoom)
      lg.stencil(self.brushOutlineStencil, "increment", 1, true)
      lg.pop()

      lg.setStencilTest("equal", 2)
      lg.setColor(0, 0, 0)
      lg.rectangle("fill",
        ix - math.floor(self.toolSize / 2),
        iy - math.floor(self.toolSize / 2),
        self.toolSize + 1,
        self.toolSize + 1)
      lg.setStencilTest()
    else
      lg.setColor(0, 0, 0)
      lg.setLineWidth(1 / self.zoom)
      lg.setLineStyle("rough")
      lg.circle("line", ix, iy, self.toolSize / 2)
    end
  end

  lg.pop()

  self.toolbar:render(x, y + h / 2 - self.toolbar:desiredHeight() / 2,
    self.toolbar:desiredWidth(), self.toolbar:desiredHeight())

  local zoomPercentString = ("%d%%"):format(self.zoom * 100)
  local zoomPercentW = lg.getFont():getWidth(zoomPercentString)
  lg.setColor(0, 0, 0, 0.4)
  lg.rectangle("fill",
    x + w - zoomPercentW,
    y + h - lg.getFont():getHeight(),
    zoomPercentW + 3,
    lg.getFont():getHeight() + 3,
    3)
  lg.setColor(1, 1, 1)
  lg.printf(zoomPercentString, x, y + h - lg.getFont():getHeight(), w, "right")

  lg.setScissor()
end

return spriteEditor
