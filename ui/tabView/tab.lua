local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local hexToColor = require "util.hexToColor"

local textMargin = 8

---@class Tab: Zap.ElementClass
---@field content Zap.Element
---@field text string
---@field active boolean
---@field font love.Font
---@operator call:Tab
local tab = zap.elementClass()

function tab:mousePressed()
  self:getParent() --[[@as TabView]]:setActiveTab(self)
end

function tab:preferredWidth()
  return self.font:getWidth(self.text) + textMargin * 2
end

function tab:render(x, y, w, h)
  if self.active or self:isHovered() then
    lg.setColor(hexToColor(0x1f1f1f))
  else
    lg.setColor(hexToColor(0x181818))
  end
  lg.rectangle("fill", x, y, w, h)

  lg.setColor(1, 1, 1)
  lg.setFont(self.font)
  lg.print(self.text, x + textMargin, y + h / 2 - self.font:getHeight() / 2)
end

return tab
