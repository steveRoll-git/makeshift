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
---@field index number
---@field layoutX number
---@field draggable boolean
---@field isDragging boolean
---@field dragStartX number
---@field dragStartY number
---@field dragX number
---@operator call:Tab
local tab = zap.elementClass()

function tab:mousePressed()
  self:getParent() --[[@as TabView]]:setActiveTab(self)
  if self.draggable then
    self.dragStartX, self.dragStartY = self:getRelativeMouse()
    local mx = self:getAbsoluteMouse()
    self.dragX = mx - self.dragStartX
    self.isDragging = true
  end
end

function tab:mouseReleased()
  if self.isDragging then
    self.isDragging = false
  end
end

function tab:mouseMoved(mx, my)
  if self.isDragging then
    local tabView = self:getParent() --[[@as TabView]]
    self.dragX = mx - self.dragStartX
    local x, _, w, _ = self:getView()
    -- Code for switching the order of tabs when dragging them
    for i, otherTab in ipairs(tabView.tabs) do
      if otherTab ~= self then
        local x2, _, w2, _ = otherTab:getView()
        local mid2 = x2 + w2 / 2
        if
            (otherTab.index > self.index and x + w >= mid2 and x + w < x2 + w2) or
            (otherTab.index < self.index and x >= x2 and x < mid2) then
          tabView:setTabIndex(self, i)
          break
        end
      end
    end
  end
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
