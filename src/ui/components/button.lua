local love = love
local lg = love.graphics

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
local Button = zap.elementClass()

function Button:mouseClicked(btn)
  if btn == 1 then
    self.onClick()
  end
end

function Button:showsText()
  return self.displayMode == "text" or self.displayMode == "textAfterImage"
end

function Button:showsImage()
  return self.displayMode == "image" or self.displayMode == "textAfterImage"
end

function Button:desiredWidth()
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

function Button:desiredHeight()
  local height = 0
  if self:showsText() then
    height = math.max(height, self.font:getHeight())
  end
  if self:showsImage() then
    height = math.max(height, self.image:getHeight())
  end
  return height
end

function Button:render(x, y, w, h)
  if self:isPressed(1) then
    lg.setColor(CurrentTheme.elementPressed)
  elseif self:isHovered() then
    lg.setColor(CurrentTheme.elementHovered)
  else
    lg.setColor(0, 0, 0, 0) -- unstyled
  end
  lg.rectangle("fill", x, y, w, h, 6)

  local totalW = self:desiredWidth()
  local foregroundColor = (self:isHovered() or self:isPressed(1)) and
      CurrentTheme.foregroundActive or
      CurrentTheme.foreground

  if self:showsImage() then
    lg.setColor(foregroundColor)
    lg.draw(self.image,
      math.floor(x + w / 2 - totalW / 2),
      math.floor(y + h / 2 - self.image:getHeight() / 2))
  end

  if self:showsText() then
    lg.setColor(foregroundColor)
    lg.setFont(self.font)
    lg.printf(self.text,
      self.alignText == "left" and x + (self.textPadding or 0) or math.floor(x + w / 2 - totalW / 2),
      math.floor(y + h / 2 - self.font:getHeight() / 2),
      totalW,
      "right")
  end
end

return Button
