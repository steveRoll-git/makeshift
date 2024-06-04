local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local fonts = require "fonts"
local hexToColor = require "util.hexToColor"
local images = require "images"

local icon = images["icons/cancel_32.png"]

local font = fonts("Inter-Regular.ttf", 16)

local padding = 8
local textMargin = 4

---@class SyntaxErrorBar: Zap.ElementClass
---@field error SyntaxError
---@operator call:SyntaxErrorBar
local syntaxErrorBar = zap.elementClass()

function syntaxErrorBar:desiredHeight()
  return math.max(font:getHeight(), icon:getHeight()) + padding * 2
end

function syntaxErrorBar:render(x, y, w, h)
  lg.setColor(hexToColor(0x181818))
  lg.rectangle("fill", x, y, w, h)

  lg.setColor(0.8, 0, 0)
  lg.draw(icon, x + padding, y + padding)
  lg.setFont(font)
  lg.print(
    ("Syntax error at (%d, %d): %s"):format(self.error.fromLine, self.error.fromColumn, self.error.message),
    x + padding + icon:getWidth() + textMargin,
    math.floor(y + h / 2 - font:getHeight() / 2))
end

return syntaxErrorBar