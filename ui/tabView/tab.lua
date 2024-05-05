local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local hexToColor = require "util.hexToColor"
local button = require "ui.button"
local images = require "images"

local textMargin = 8
local iconTextMargin = 6

---@class Tab: Zap.ElementClass
---@field content Zap.Element
---@field text string
---@field icon love.Image
---@field active boolean
---@field font love.Font
---@field index number
---@field layoutX number
---@field draggable boolean
---@field closable boolean
---@field isDragging boolean
---@field dragStartX number
---@field dragStartY number
---@field dragX number
---@operator call:Tab
local tab = zap.elementClass()

function tab:init()
  self.closeButton = button()
  self.closeButton.displayMode = "image"
  self.closeButton.image = images["icons/close_18.png"]
  self.closeButton.onClick = function()
    self:parentTabView():closeTab(self)
  end
end

function tab:parentTabView()
  return self:getParent() --[[@as TabView]]
end

function tab:mousePressed(btn)
  if btn == 1 then
    self:parentTabView():setActiveTab(self)
    if self.draggable then
      self.dragStartX, self.dragStartY = self:getRelativeMouse()
      local mx = self:getAbsoluteMouse()
      self.dragX = mx - self.dragStartX
      self.isDragging = true
    end
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

function tab:mouseClicked(btn)
  if btn == 3 and self.closable then
    self:parentTabView():closeTab(self)
  end
end

function tab:desiredWidth()
  return self.font:getWidth(self.text) + textMargin * 2
      + (self.closable and self.closeButton:desiredWidth() or 0)
      + (self.icon and (self.icon:getWidth() + iconTextMargin) or 0)
end

function tab:render(x, y, w, h)
  local cornerRadius = 6

  lg.setScissor(x - 1, y, w + 2, h)
  if self.active or self:isHovered() then
    lg.setColor(hexToColor(0x1f1f1f))
  else
    lg.setColor(hexToColor(0x181818))
  end
  lg.rectangle("fill", x, y, w, h + cornerRadius, cornerRadius)

  if self.active then
    lg.setColor(hexToColor(0x2b2b2b))
    lg.setLineStyle("rough")
    lg.setLineWidth(1)
    lg.rectangle("line", x, y + 2, w, h + cornerRadius, cornerRadius)
  end

  lg.setScissor()

  local textX = x + textMargin
  local textY = y + h / 2 - self.font:getHeight() / 2

  if self.icon then
    lg.setColor(1, 1, 1)
    lg.draw(self.icon, math.floor(textX), math.floor(y + h / 2 - self.icon:getHeight() / 2))
    textX = textX + self.icon:getWidth() + iconTextMargin
  end

  lg.setColor(1, 1, 1)
  lg.setFont(self.font)
  lg.print(self.text, textX, textY)

  if self.closable then
    lg.setColor(1, 1, 1)
    self.closeButton:render(
      x + w - self.closeButton:desiredWidth() - 4,
      textY + self.font:getHeight() / 2 - self.closeButton:desiredHeight() / 2 + math.floor(self.font:getHeight() / 10),
      self.closeButton:desiredWidth(),
      self.closeButton:desiredHeight())
  end
end

return tab
