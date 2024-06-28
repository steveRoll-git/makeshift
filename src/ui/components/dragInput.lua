local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local viewTools = require "util.viewTools"
local clamp = require "util.clamp"
local TempEditor = require "ui.components.tempEditor"

local defaultNumberFormat = "%d"

---@class DragInput: Zap.ElementClass
---@field targetObject table
---@field targetKey any
---@field font love.Font
---@field numberFormat? string
---@field minValue? number
---@field maxValue? number
---@field onChange? function
---@operator call:DragInput
local DragInput = zap.elementClass()

---Returns the current value of the target property.
---@return number
function DragInput:currentValue()
  return self.targetObject[self.targetKey]
end

---Sets the target object's property to `value`.
---@param value number
function DragInput:setValue(value)
  self.targetObject[self.targetKey] = clamp(value, self.minValue or -math.huge, self.maxValue or math.huge)
  if self.onChange then
    self.onChange()
  end
end

function DragInput:mouseClicked(button)
  if button == 1 then
    local x, y, w, h = self:getView()
    local textWidth = math.max(self.font:getWidth(tostring(self:currentValue())), w)
    x, y, w, h = viewTools.padding(math.floor(x + w / 2 - textWidth / 2), y, textWidth, h, -3)
    local tempEditor = TempEditor(tostring(self:currentValue()))
    tempEditor.textEditor.centerHorizontally = true
    tempEditor:setFont(self.font)
    tempEditor.writeValue = function(value)
      local asNumber = tonumber(value)
      if asNumber then
        self:setValue(asNumber)
      end
    end
    OpenPopup(tempEditor, x, y, w, h)
  end
end

function DragInput:render(x, y, w, h)
  lg.setColor(CurrentTheme.backgroundInactive)
  lg.rectangle("fill", x, y, w, h, 3)

  lg.setColor(CurrentTheme.foregroundActive)
  lg.setFont(self.font)
  lg.printf(
    (self.numberFormat or defaultNumberFormat):format(self:currentValue()),
    x,
    math.floor(y + h / 2 - self.font:getHeight() / 2),
    w,
    "center")
end

return DragInput
