local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local images = require "images"
local fontCache = require "util.fontCache"
local viewTools = require "util.viewTools"
local dragInput = require "ui.dragInput"

local font = fontCache.get("Inter-Regular.ttf", 14)

---@alias DataPanel.FieldType "vec2"

---@class DataPanel.FieldModel
---@field type DataPanel.FieldType
---@field text string

---@class DataPanel.Vec2Model: DataPanel.FieldModel
---@field targetObject table
---@field xKey any
---@field yKey any

---@class DataPanel.Field
---@field type DataPanel.FieldType
---@field text string

---@class DataPanel.Vec2Field: DataPanel.Field
---@field xInput DragInput
---@field yInput DragInput

---@class DataPanel: Zap.ElementClass
---@field fields DataPanel.Field[]
---@field icon love.Image
---@field text string
---@operator call:DataPanel
local dataPanel = zap.elementClass()

---@param fields DataPanel.FieldModel[]
function dataPanel:init(fields)
  self.fields = {}
  for _, f in ipairs(fields) do
    if f.type == "vec2" then
      ---@cast f DataPanel.Vec2Model
      local xInput = dragInput()
      xInput.font = font
      xInput.targetObject = f.targetObject
      xInput.targetKey = f.xKey
      xInput.numberFormat = "%.1f"
      local yInput = dragInput()
      yInput.font = font
      yInput.targetObject = f.targetObject
      yInput.targetKey = f.yKey
      yInput.numberFormat = "%.1f"
      ---@type DataPanel.Vec2Field
      local field = {
        type = "vec2",
        text = f.text,
        xInput = xInput,
        yInput = yInput
      }
      table.insert(self.fields, field)
    end
  end
end

function dataPanel:render(x, y, w, h)
  lg.setColor(CurrentTheme.backgroundBright)
  lg.rectangle("fill", x, y, w, h, 4)

  x, y, w, h = viewTools.padding(x, y, w, h, 7)
  lg.setColor(CurrentTheme.foregroundActive)
  lg.draw(self.icon, x, math.floor(y + font:getHeight() / 2 - self.icon:getHeight() / 2))
  lg.setFont(font)
  lg.print(self.text, x + self.icon:getWidth() + 2, y)

  for _, f in ipairs(self.fields) do
    y = y + font:getHeight() + 6
    lg.setColor(CurrentTheme.foregroundActive)
    lg.print(f.text, x, y)

    if f.type == "vec2" then
      ---@cast f DataPanel.Vec2Field
      local inputHeightPadding = 2
      local inputLabelMargin = 4
      local separateInputMargin = 6
      local inputWidth = font:getWidth("-4444.4")
      local totalColumnWidth = inputWidth * 2 +
          font:getWidth("X") +
          font:getWidth("Y") +
          inputLabelMargin * 2 +
          separateInputMargin

      local cx = x + w - totalColumnWidth
      lg.setColor(CurrentTheme.foregroundActive)
      lg.print("X", cx, y)
      cx = cx + font:getWidth("X") + inputLabelMargin
      f.xInput:render(cx, y - inputHeightPadding, inputWidth, font:getHeight() + inputHeightPadding * 2)

      cx = cx + inputWidth + separateInputMargin
      lg.setColor(CurrentTheme.foregroundActive)
      lg.print("Y", cx, y)
      cx = cx + font:getWidth("Y") + inputLabelMargin
      f.yInput:render(cx, y - inputHeightPadding, inputWidth, font:getHeight() + inputHeightPadding * 2)
    end
  end
end

return dataPanel
