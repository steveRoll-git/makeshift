local love = love
local lg = love.graphics

local lerp = require "util.lerp"

local titleBarHeight = 28
local titleFont = lg.newFont(FontName, titleBarHeight - 12)
local cornerSize = 7

local closeButton = {
  action = "close",
  draw = function()
    lg.setColor(1, 1, 1)
    lg.setLineWidth(1)
    local a = titleBarHeight / 3
    local b = titleBarHeight - a
    lg.line(a, a, b, b)
    lg.line(b, a, a, b)
  end
}
local maximizeButton = {
  action = "maximize",
  draw = function()
    lg.setColor(1, 1, 1)
    lg.setLineWidth(1)
    local w = math.floor(titleBarHeight / 2)
    local h = math.floor(titleBarHeight / 3)
    lg.rectangle("line", titleBarHeight / 2 - w / 2, titleBarHeight / 2 - h / 2, w, h)
  end
}

local window = {}
window.__index = window

window.titleBarHeight = titleBarHeight

window.allButtons = { closeButton, maximizeButton }
window.onlyCloseButton = { closeButton }

function window.new(content, title, width, height, x, y, menuStrip)
  local self = setmetatable({}, window)
  self:init(content, title, width, height, x, y, menuStrip)
  return self
end

function window:init(content, title, width, height, x, y, menuStrip)
  self.content = content
  self.content.window = self
  if menuStrip then
    self.menuStrip = menuStrip
    self.menuStrip.window = self
  end
  self.title = title
  self:resize(width, height)
  self.x = x
  self.y = y
  self.stencilWhole = function()
    lg.rectangle("fill", 0, 0, self.width, self.height, self:cornerSize())
  end
  self.stencilContent = function()
    local offset = self:contentYOffset()
    lg.rectangle("fill", 0, offset, self.width, self.height - offset)
  end
end

function window:cornerSize()
  return self.maximizeAnim and lerp(cornerSize, 0, self.maximizeAnim) or (self.maximized and 0 or cornerSize)
end

function window:inside(x, y)
  return x >= self.x and x <= self.x + self.width and y >= self.y and y <= self.y + self.height
end

function window:contentYOffset()
  return titleBarHeight + (self.menuStrip and self.menuStrip.height or 0)
end

function window:getTitleButtonOver(x, y)
  if y < self.y or y > self.y + titleBarHeight or x > self.x + self.width then
    return nil
  end
  for i = 1, #self.buttons do
    if x >= self.x + self.width - titleBarHeight * i then
      return i
    end
  end
end

function window:openModalChild(w)
  self.modalChild = w
  w.modalParent = self
  self.modalOverlayAlpha = 0
  AddTween(self, 0.1, { modalOverlayAlpha = 0.6 })
end

function window:resize(w, h)
  self.width = w
  self.height = h
  local prevW, prevH = self.content.windowWidth, self.content.windowHeight
  self.content.windowWidth = w
  self.content.windowHeight = h - self:contentYOffset()
  if self.content.resize then
    self.content:resize(self.content.windowWidth, self.content.windowHeight, prevW, prevH)
  end
end

function window:draw()
  local outlineColor = self.maximizeAnim and (1 - self.maximizeAnim) or (self.maximized and 0 or 1)

  if self.closeAnim then
    local amount = self.closeAnim / 8
    lg.translate(self.width / 2 * amount, self.height / 2 * amount)
    lg.scale(1 - amount)
    lg.setColor(1, 1, 1, 1 - self.closeAnim)
    lg.draw(self.canvas)
    return
  end

  lg.setColor(0.2, 0.2, 0.2, 0.98)
  lg.rectangle("fill", 0, 0, self.width, self.height, self:cornerSize())

  PushStencil(self.stencilWhole)

  lg.push()
  lg.translate(self.width - titleBarHeight, 0)
  for i, btn in ipairs(self.buttons) do
    lg.setColor(1, 1, 1)
    lg.setLineWidth(1)
    btn.draw()
    if self.buttonDown == i then
      lg.setColor(1, 1, 1, 0.5)
      lg.rectangle("fill", 0, 0, titleBarHeight, titleBarHeight)
    elseif self.buttonOver == i then
      lg.setColor(1, 1, 1, 0.2)
      lg.rectangle("fill", 0, 0, titleBarHeight, titleBarHeight)
    end
    lg.setColor(1, 1, 1)
    lg.line(0, 0, 0, titleBarHeight)
    lg.translate(-titleBarHeight, 0)
  end
  lg.pop()

  lg.setColor(1, 1, 1)
  lg.setFont(titleFont)
  lg.print(self.title, math.floor(cornerSize), math.floor(titleBarHeight / 2 - titleFont:getHeight() / 2))


  if self.menuStrip then
    lg.push()
    lg.translate(0, titleBarHeight)
    self.menuStrip:draw()
    lg.pop()
  end

  lg.push()
  PushStencil(self.stencilContent)
  lg.translate(0, self:contentYOffset())
  self.content:draw()
  lg.pop()

  if self.modalChild then
    lg.setColor(0, 0, 0, self.modalOverlayAlpha)
    self.stencilContent()
  end
  PopStencil(self.stencilContent)

  PopStencil(self.stencilWhole)

  if self.resizable and not self.maximized then
    lg.setColor(1, 1, 1, outlineColor)
    lg.setLineWidth(1)
    lg.line(self.width - cornerSize - 1, self.height, self.width, self.height - cornerSize - 1)
    lg.line(self.width - cornerSize - 6, self.height, self.width, self.height - cornerSize - 6)
  end

  lg.setColor(1, 1, 1)
  lg.setLineWidth(1)
  lg.line(0, titleBarHeight, self.width, titleBarHeight)
  lg.setColor(1, 1, 1, outlineColor)
  lg.rectangle("line", 0, 0, self.width, self.height, self:cornerSize())
end

return window
