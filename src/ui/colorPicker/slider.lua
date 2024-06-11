local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local sign = require "util.sign"

local arrowWidth = 10
local arrowHeight = 6

local arrowPolygon = {
  -arrowWidth / 2, -arrowHeight,
  arrowWidth / 2, -arrowHeight,
  0, 0
}

-- This ImageData is kept around to generate the images for each slider.
local imageData = love.image.newImageData(256, 1)

---@class ColorPickerSlider: Zap.ElementClass
---@field colorFunc fun(a:number, b:number, c:number): number, number, number The color function that converts the model to RGB values.
---@field model number[] The table that contains the color to be modified.
---@field modelKey number The index of the component in the `model` that this slider will modify.
---@field minValue number The smallest value of the slider.
---@field maxValue number The largest value of the slider.
---@field image love.Image
---@field onChange fun() Called when the slider's value changes.
---@operator call:ColorPickerSlider
local slider = zap.elementClass()

---Updates the slider's image according to the model's current values.
function slider:updateImage()
  local color = { unpack(self.model) }
  imageData:mapPixel(function(x, y)
    color[self.modelKey] = self.minValue + (self.maxValue - self.minValue) * (x / imageData:getWidth())
    return self.colorFunc(unpack(color))
  end)
  if self.image then
    self.image:replacePixels(imageData)
  else
    self.image = love.graphics.newImage(imageData)
  end
end

function slider:getValue()
  return self.model[self.modelKey]
end

function slider:setValue(v)
  self.model[self.modelKey] = math.min(math.max(v, self.minValue), self.maxValue)
  self.onChange()
end

---Updates the slider's value when the mouse is clicked or dragged on it.
function slider:dragValue()
  local mx, _ = self:getRelativeMouse()
  local _, _, w, _ = self:getView()
  self:setValue(self.minValue + (mx / w) * (self.maxValue - self.minValue))
end

function slider:mousePressed(btn)
  if btn == 1 then
    self:dragValue()
  end
end

function slider:mouseMoved()
  if self:isPressed(1) then
    self:dragValue()
  end
end

function slider:wheelMoved(x, y)
  self:setValue(self:getValue() + sign(y))
end

function slider:render(x, y, w, h)
  lg.setColor(1, 1, 1)
  lg.draw(self.image, x, y + arrowHeight, 0, w / self.image:getWidth(), h - arrowHeight)

  lg.push()
  lg.translate(math.floor(x + self:getValue() / self.maxValue * w), math.floor(y + arrowHeight))
  lg.setColor(1, 1, 1)
  lg.polygon("fill", arrowPolygon)
  lg.pop()
end

return slider
