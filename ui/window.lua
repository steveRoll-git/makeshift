local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local button = require "ui.button"
local images = require "images"
local hexToColor = require "util.hexToColor"
local clamp = require "util.clamp"
local viewTools = require "util.viewTools"

---@class Window: Zap.ElementClass
---@field icon love.Image
---@field title string
---@field titleFont love.Font
---@field content Zap.Element
---@field x number
---@field y number
---@field width number
---@field height number
---@field closable boolean
---@operator call:Window
local window = zap.elementClass()

function window:init()
  self.closeButton = button()
  self.closeButton.displayMode = "image"
  self.closeButton.image = images["icons/close_18.png"]
  self.closeButton.onClick = function()
    CloseWindow(self)
  end
end

function window:desiredWidth()
  return self.width
end

function window:desiredHeight()
  return self.height
end

function window:titleBarHeight()
  return self.titleFont:getHeight() + 16
end

function window:clampPosition()
  self.x = clamp(self.x, -self.width / 2, lg.getWidth() - self.width / 2)
  self.y = clamp(self.y, 0, lg.getHeight() - self.height / 2)
end

function window:mousePressed(btn)
  if btn == 1 then
    self.dragging = true
    self.dragX, self.dragY = self:getRelativeMouse()
  end
end

function window:mouseReleased(btn)
  if btn == 1 and self.dragging then
    self.dragging = false
  end
end

function window:mouseMoved(x, y, dx, dy)
  if self.dragging then
    local mx, my = self:getAbsoluteMouse()
    self.x = mx - self.dragX
    self.y = my - self.dragY
    self:clampPosition()
  end
end

function window:render(x, y, w, h)
  local cornerRadius = 6
  lg.setColor(hexToColor(0x1f1f1f))
  lg.rectangle("fill", x, y, w, self:titleBarHeight() + cornerRadius, cornerRadius)
  lg.setColor(hexToColor(0x2b2b2b))
  lg.setLineStyle("rough")
  lg.setLineWidth(1)
  lg.rectangle("line", x, y, w, self:titleBarHeight() + cornerRadius, cornerRadius)

  lg.setColor(1, 1, 1)
  local ex = x + 6
  if self.icon then
    lg.draw(self.icon, ex, math.floor(y + self:titleBarHeight() / 2 - self.icon:getHeight() / 2))
    ex = ex + self.icon:getWidth() + 3
  end
  lg.setFont(self.titleFont)
  lg.print(self.title,
    ex,
    math.floor(y + self:titleBarHeight() / 2 - self.titleFont:getHeight() / 2))

  if self.closable then
    self.closeButton:render(viewTools.padding(
      x + w - self:titleBarHeight(),
      y,
      self:titleBarHeight(),
      self:titleBarHeight(),
      1))
  end

  lg.setColor(hexToColor(0x181818))
  lg.rectangle("fill", x, y + self:titleBarHeight(), w, h - self:titleBarHeight())

  PushScissor(x, y + self:titleBarHeight(), w, h - self:titleBarHeight())
  self.content:render(x, y + self:titleBarHeight(), w, h - self:titleBarHeight())
  PopScissor()

  lg.setColor(hexToColor(0x2b2b2b))
  lg.setLineStyle("rough")
  lg.setLineWidth(1)
  lg.line(
    x, y + self:titleBarHeight(),
    x, y + h,
    x + w, y + h,
    x + w, y + self:titleBarHeight())
end

return window
