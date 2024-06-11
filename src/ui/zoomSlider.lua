local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local fonts = require "fonts"
local images = require "images"

local icon = images["icons/zoom_in_14.png"]

local font = fonts("Inter-Regular.ttf", 16)

---@class ZoomSlider: Zap.ElementClass
---@field targetTable {zoom: number}
---@operator call:ZoomSlider
local zoomSlider = zap.elementClass()

function zoomSlider:percentString()
  return ("%d%%"):format(self.targetTable.zoom * 100)
end

function zoomSlider:desiredWidth()
  return font:getWidth(self:percentString()) + icon:getWidth()
end

function zoomSlider:desiredHeight()
  return font:getHeight()
end

function zoomSlider:render(x, y, w, h)
  lg.setColor(0, 0, 0, 0.6)
  lg.rectangle("fill", x, y, w + 3, h + 3, 3)

  lg.setColor(0.8, 0.8, 0.8)
  lg.draw(icon, math.floor(x + w - icon:getWidth()), math.floor(y + h / 2 - icon:getHeight() / 2))

  lg.setColor(1, 1, 1)
  lg.setFont(font)
  lg.print(self:percentString(), math.floor(x + 2), math.floor(y + h / 2 - font:getHeight() / 2))
end

return zoomSlider
