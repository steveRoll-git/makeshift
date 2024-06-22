local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local clamp = require "util.clamp"

local size = 14

---@class Scrollbar.Thumb: Zap.ElementClass
---@operator call:Scrollbar.Thumb
local Thumb = zap.elementClass()

---@param scrollbar Scrollbar
function Thumb:init(scrollbar)
  self.scrollbar = scrollbar
end

function Thumb:mousePressed(button)
  if button == 1 then
    self.pressX, self.pressY = self:getRelativeMouse()
  end
end

function Thumb:mouseMoved()
  if self:isPressed(1) then
    local ax, ay = self:getAbsoluteMouse()
    local newX, newY = ax - self.pressX, ay - self.pressY
    local x, y, w, h = self.scrollbar:getView()
    local value = self.scrollbar.direction == "x" and
        math.floor((newX - x) / w * self.scrollbar:getContentSize()) or
        math.floor((newY - y) / h * self.scrollbar:getContentSize())
    self.scrollbar:setValue(clamp(value, 0, self.scrollbar:maximumScroll()))
  end
end

function Thumb:render(x, y, w, h)
  if self:isPressed(1) then
    lg.setColor(CurrentTheme.elementPressed)
  elseif self:isHovered() then
    lg.setColor(CurrentTheme.elementHovered)
  else
    lg.setColor(CurrentTheme.elementNeutral)
  end
  lg.rectangle("fill", x, y, w, h, size / 2)
end

---@class Scrollbar: Zap.ElementClass
---@field direction "x" | "y" The direction this scrollbar should scroll in.
---@field contentSize number | fun(): number The size of the content being viewed.
---@field viewSize number | fun(): number The size of the view.
---@field targetTable table The table whose property the scrollbar will control.
---@field targetField string The field in targetTable whose value will be controlled.
---@operator call:Scrollbar
local Scrollbar = zap.elementClass()

function Scrollbar:init()
  self.thumb = Thumb(self)
end

function Scrollbar:desiredWidth()
  return size
end

function Scrollbar:desiredHeight()
  return size
end

---Returns the current value in `targetTable`.
---@return number
function Scrollbar:currentValue()
  return self.targetTable[self.targetField]
end

---Sets the current value in `targetTable`.
---@param value number
function Scrollbar:setValue(value)
  self.targetTable[self.targetField] = value
end

---@return number
function Scrollbar:getViewSize()
  if type(self.viewSize) == "function" then
    return self.viewSize()
  end
  return self.viewSize --[[@as number]]
end

---@return number
function Scrollbar:getContentSize()
  if type(self.contentSize) == "function" then
    return self.contentSize()
  end
  return self.contentSize --[[@as number]]
end

---Returns the highest extent to which this scrollbar can scroll.
---@return number
function Scrollbar:maximumScroll()
  return self:getContentSize() - self:getViewSize()
end

function Scrollbar:render(x, y, w, h)
  assert(self.direction == "x" or self.direction == "y", "no direction set for this scrollbar!")

  local dx = self.direction == "x"
  local dy = self.direction == "y"
  local viewSize = self:getViewSize()
  local contentSize = self:getContentSize()
  self.thumb:render(
    dx and x + self:currentValue() / contentSize * w or x,
    dy and y + self:currentValue() / contentSize * h or y,
    dx and viewSize / contentSize * w or w,
    dy and viewSize / contentSize * h or h
  )
end

return Scrollbar
