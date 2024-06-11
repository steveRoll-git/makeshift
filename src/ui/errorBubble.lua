local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local fonts = require "fonts"

local font = fonts("Inter-Regular.ttf", 16)
local defaultWidth = 600

local tailPolygon = {
  -8, 0,
  0, -6,
  0, 6
}

---@class ErrorBubble: Zap.ElementClass
---@field tailY number?
---@operator call:ErrorBubble
local errorBubble = zap.elementClass()

errorBubble.padding = 8

---@param text string
function errorBubble:init(text)
  self.text = lg.newText(font)
  self.text:addf(text, defaultWidth, "left", 0, 0)
end

function errorBubble:desiredWidth()
  return self.text:getWidth() + errorBubble.padding * 2
end

function errorBubble:desiredHeight()
  return self.text:getHeight() + errorBubble.padding * 2
end

function errorBubble:render(x, y, w, h)
  lg.setColor(CurrentTheme.backgroundError)
  lg.rectangle("fill", x, y, w, h, 4, 4, 4)
  if self.tailY then
    lg.push()
    lg.translate(x, y + self.tailY)
    lg.polygon("fill", tailPolygon)
    lg.pop()
  end

  lg.setColor(CurrentTheme.foregroundActive)
  lg.draw(self.text, x + errorBubble.padding, y + errorBubble.padding)
end

return errorBubble
