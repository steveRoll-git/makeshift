local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local fontCache = require "util.fontCache"

local font = fontCache.get("Inter-Regular.ttf", 16)
local defaultWidth = 600

local tailPolygon = {
  -8, 0,
  0, -6,
  0, 6
}

---@class ErrorBubble: Zap.ElementClass
---@field tailY number?
---@operator call:ErrorBubble
local ErrorBubble = zap.elementClass()

ErrorBubble.padding = 8

---@param text string
function ErrorBubble:init(text)
  self.text = lg.newText(font)
  self.text:addf(text, defaultWidth, "left", 0, 0)
end

function ErrorBubble:desiredWidth()
  return self.text:getWidth() + ErrorBubble.padding * 2
end

function ErrorBubble:desiredHeight()
  return self.text:getHeight() + ErrorBubble.padding * 2
end

function ErrorBubble:render(x, y, w, h)
  lg.setColor(CurrentTheme.backgroundError)
  lg.rectangle("fill", x, y, w, h, 4, 4, 4)
  if self.tailY then
    lg.push()
    lg.translate(x, y + self.tailY)
    lg.polygon("fill", tailPolygon)
    lg.pop()
  end

  lg.setColor(CurrentTheme.foregroundActive)
  lg.draw(self.text, x + ErrorBubble.padding, y + ErrorBubble.padding)
end

return ErrorBubble
