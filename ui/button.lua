local love = love
local lg = love.graphics

local hexToColor = require "util.hexToColor"
local zap = require "lib.zap.zap"

---@class Button: Zap.ElementClass
---@field image love.Image
---@field text string
---@field font love.Font
---@field onClick fun()
---@field displayMode "image" | "text" | "textAfterImage"
---@field textImageMargin number
---@field alignText? "left" | "center"
---@field textPadding? number
---@operator call:Button
local button = zap.elementClass()

function button:mouseClicked(btn)
  if btn == 1 then
    self.onClick()
  end
end

function button:showsText()
  return self.displayMode == "text" or self.displayMode == "textAfterImage"
end

function button:showsImage()
  return self.displayMode == "image" or self.displayMode == "textAfterImage"
end

function button:desiredWidth()
  local totalW = 0
  if self:showsText() then
    totalW = totalW + self.font:getWidth(self.text)
  end
  if self:showsImage() then
    totalW = totalW + self.image:getWidth()
  end
  if self:showsText() and self:showsImage() then
    totalW = totalW + (self.textImageMargin or 0)
  end
  return totalW
end

function button:desiredHeight()
  local height = 0
  if self:showsText() then
    height = math.max(height, self.font:getHeight())
  end
  if self:showsImage() then
    height = math.max(height, self.image:getHeight())
  end
  return height
end

function button:render(x, y, w, h)
  if self:isPressed(1) then
    lg.setColor(1, 1, 1, 0.2)
  elseif self:isHovered() then
    lg.setColor(1, 1, 1, 0.08)
  else
    lg.setColor(0, 0, 0, 0)
  end
  lg.rectangle("fill", x, y, w, h, 6)

  local totalW = self:desiredWidth()

  if self:showsImage() then
    lg.setColor(hexToColor(0xcccccc))
    lg.draw(self.image,
      math.floor(x + w / 2 - totalW / 2),
      math.floor(y + h / 2 - self.image:getHeight() / 2))
  end

  if self:showsText() then
    lg.setColor(hexToColor(0xcccccc))
    lg.setFont(self.font)
    lg.printf(self.text,
      self.alignText == "left" and x + (self.textPadding or 0) or math.floor(x + w / 2 - totalW / 2),
      math.floor(y + h / 2 - self.font:getHeight() / 2),
      totalW,
      "right")
  end
end

return button
