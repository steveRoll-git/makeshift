local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local slider = require "ui.colorPicker.slider"
local hsvToRgb = require "util.hsvToRgb"
local rgbToHsv = require "util.rgbToHsv"
local hexToColor = require "util.hexToColor"

local labelFont = lg.getFont()

local slidersHSV = {
  {
    label = "H",
    minValue = 0,
    maxValue = 360,
  },
  {
    label = "S",
    minValue = 0,
    maxValue = 100,
  },
  {
    label = "V",
    minValue = 0,
    maxValue = 100,
  },
}

---@class ColorPicker: Zap.ElementClass
---@field color number[]
---@field sliders ColorPickerSlider[]
---@operator call:ColorPicker
local colorPicker = zap.elementClass()

function colorPicker:init(color)
  self.color = color
  self.modeledColor = { rgbToHsv(unpack(color)) }

  self.sliders = {}
  for i = 1, 3 do
    local sliderInfo = slidersHSV[i]
    local theSlider = slider()
    theSlider.model = self.modeledColor
    theSlider.modelKey = i
    theSlider.minValue = sliderInfo.minValue
    theSlider.maxValue = sliderInfo.maxValue
    theSlider.colorFunc = hsvToRgb
    table.insert(self.sliders, theSlider)
    theSlider.onChange = function()
      for j, s in ipairs(self.sliders) do
        if j ~= theSlider.modelKey then
          s:updateImage()
        end
      end
      self.color[1], self.color[2], self.color[3], self.color[4] = hsvToRgb(unpack(self.modeledColor))
    end
    theSlider:updateImage()
  end
end

function colorPicker:render(x, y, w, h)
  lg.setColor(hexToColor(0x1f1f1f))
  lg.rectangle("fill", x, y, w, h, 6)

  local padding = 6
  x = x + padding
  y = y + padding
  w = w - padding * 2
  h = h - padding * 2

  local sliderHeight = h / #self.sliders
  for i, s in ipairs(self.sliders) do
    local sliderY = y + sliderHeight * (i - 1)
    lg.setColor(1, 1, 1)
    lg.setFont(labelFont)
    lg.print(slidersHSV[i].label, x, sliderY + sliderHeight / 2 - labelFont:getHeight() / 2)
    lg.printf(("%d"):format(s:getValue()), x, sliderY + sliderHeight / 2 - labelFont:getHeight() / 2, w, "right")
    local leftLabelWidth = labelFont:getWidth("H ")
    local rightLabelWidth = labelFont:getWidth(" 999")
    s:render(x + leftLabelWidth, sliderY, w - leftLabelWidth - rightLabelWidth, sliderHeight)
  end
end

return colorPicker
