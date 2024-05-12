local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local hexToColor = require "util.hexToColor"
local textEditor = require "ui.textEditor"
local viewTools = require "util.viewTools"

---@class DragInputTempEditor: Zap.ElementClass
---@operator call:DragInputTempEditor
local tempEditor = zap.elementClass()

---@param parent DragInput
---@param viewWidth number
function tempEditor:init(parent, viewWidth)
  local valueString = tostring(parent:currentValue())
  self.dragInput = parent
  self.textEditor = textEditor()
  self.textEditor.font = parent.font
  self.textEditor.centerHorizontally = true
  self.textEditor.centerVertically = true
  self.textEditor:setText(valueString)
  self.textEditor:selectAll()
end

function tempEditor:writeValue()
  local value = tonumber(self.textEditor:getString())
  if value then
    self.dragInput:setValue(value)
  end
end

function tempEditor:keyPressed(key)
  self.textEditor:keyPressed(key)
  if key == "escape" then
    self.cancel = true
    ClosePopup()
  elseif key == "return" or key == "kpenter" then
    ClosePopup()
  end
end

function tempEditor:textInput(text)
  self.textEditor:textInput(text)
end

function tempEditor:popupClosed()
  if not self.cancel then
    self:writeValue()
  end
end

function tempEditor:render(x, y, w, h)
  lg.setColor(hexToColor(0x181818))
  lg.rectangle("fill", x, y, w, h, 3)
  self.textEditor:render(x, y, w, h)
end

---@class DragInput: Zap.ElementClass
---@field targetObject table
---@field targetKey any
---@field font love.Font
---@operator call:DragInput
local dragInput = zap.elementClass()

---Returns the current value of the target property.
---@return number
function dragInput:currentValue()
  return self.targetObject[self.targetKey]
end

---Sets the target object's property to `value`.
---@param value number
function dragInput:setValue(value)
  self.targetObject[self.targetKey] = value
end

function dragInput:mouseClicked(button)
  if button == 1 then
    local x, y, w, h = self:getView()
    local textWidth = math.max(self.font:getWidth(tostring(self:currentValue())), w)
    x, y, w, h = viewTools.padding(math.floor(x + w / 2 - textWidth / 2), y, textWidth, h, -3)
    OpenPopup(tempEditor(self, w), x, y, w, h)
  end
end

function dragInput:render(x, y, w, h)
  lg.setColor(hexToColor(0x181818))
  lg.rectangle("fill", x, y, w, h, 3)

  lg.setColor(1, 1, 1)
  lg.setFont(self.font)
  lg.printf(
    ("%.1f"):format(self:currentValue()),
    x,
    math.floor(y + h / 2 - self.font:getHeight() / 2),
    w,
    "center")
end

return dragInput
