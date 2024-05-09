local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local hexToColor = require "util.hexToColor"

---@class DragInput: Zap.ElementClass
---@field targetObject table
---@field targetKey any
---@field font love.Font
---@operator call:DragInput
local dragInput = zap.elementClass()

function dragInput:render(x, y, w, h)
  lg.setColor(hexToColor(0x181818))
  lg.rectangle("fill", x, y, w, h, 3)

  lg.setColor(1, 1, 1)
  lg.setFont(self.font)
  lg.printf(
    ("%.1f"):format(self.targetObject[self.targetKey]),
    x,
    math.floor(y + h / 2 - self.font:getHeight() / 2),
    w,
    "center")
end

return dragInput
