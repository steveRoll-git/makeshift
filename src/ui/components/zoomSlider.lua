local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local fontCache = require "util.fontCache"
local images = require "images"

local icon = images["icons/zoom_in_14.png"]

local font = fontCache.get("Inter-Regular.ttf", 16)

---@class ZoomSlider: Zap.ElementClass
---@field targetTable {zoom: number}
---@operator call:ZoomSlider
local ZoomSlider = zap.elementClass()

function ZoomSlider:percentString()
  return ("%d%%"):format(self.targetTable.zoom * 100)
end

function ZoomSlider:desiredWidth()
  return font:getWidth(self:percentString()) + icon:getWidth()
end

function ZoomSlider:desiredHeight()
  return font:getHeight()
end

function ZoomSlider:render(x, y, w, h)
  lg.setColor(CurrentTheme.backgroundOverlay)
  lg.rectangle("fill", x, y, w + 3, h + 3, 3)

  lg.setColor(CurrentTheme.foreground)
  lg.draw(icon, math.floor(x + w - icon:getWidth()), math.floor(y + h / 2 - icon:getHeight() / 2))

  lg.setColor(CurrentTheme.foregroundActive)
  lg.setFont(font)
  lg.print(self:percentString(), math.floor(x + 2), math.floor(y + h / 2 - font:getHeight() / 2))
end

return ZoomSlider
