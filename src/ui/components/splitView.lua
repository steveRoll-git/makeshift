local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local TabView = require "ui.components.tabView"
local clamp = require "util.clamp"
local viewTools = require "util.viewTools"

local splitterWidth = 6

local minimumSplitSize = 200

---@class SplitViewSplitter: Zap.ElementClass
---@operator call:SplitViewSplitter
local Splitter = zap.elementClass()

---@param splitView SplitView
function Splitter:init(splitView)
  self.splitView = splitView
end

function Splitter:getCursor()
  return love.mouse.getSystemCursor(self.splitView.orientation == "horizontal" and "sizens" or "sizewe")
end

function Splitter:mousePressed(button)
  if button == 1 then
    self.offsetX, self.offsetY = self:getRelativeMouse()
  end
end

function Splitter:mouseMoved()
  if self:isPressed(1) then
    local mx, my = self:getAbsoluteMouse()
    if self.splitView.orientation == "horizontal" then
      self.splitView.splitDistance = my - self.offsetY + splitterWidth / 2
    else
      self.splitView.splitDistance = mx - self.offsetX + splitterWidth / 2
    end
    self.splitView:clampSplitDistance()
  end
end

---@class SplitView: Zap.ElementClass
---@field side1 Zap.Element
---@field side2 Zap.Element
---@field orientation SplitOrientation
---@field splitDistance number
---@operator call:SplitView
local SplitView = zap.elementClass()

function SplitView:init()
  self.splitter = Splitter(self)
end

function SplitView:clampSplitDistance()
  local _, _, w, h = self:getView()
  self.splitDistance = clamp(
    self.splitDistance,
    minimumSplitSize,
    (self.orientation == "horizontal" and h or w) - minimumSplitSize)
end

function SplitView:resized(w, h, prevW, prevH)
  self:clampSplitDistance()
end

function SplitView:render(x, y, w, h)
  local horizontal = self.orientation == "horizontal"
  local vertical = self.orientation == "vertical"

  assert(horizontal or vertical, "no orientation set for this splitter!")

  viewTools.renderSplit(
    x, y, w, h,
    self.side1, self.side2,
    self.orientation,
    self.splitDistance, true
  )

  self.splitter:render(
    horizontal and x or x + self.splitDistance - splitterWidth / 2,
    vertical and y or y + self.splitDistance - splitterWidth / 2,
    horizontal and w or splitterWidth,
    vertical and h or splitterWidth
  )

  lg.setColor(CurrentTheme.outline)
  lg.setLineStyle("rough")
  lg.setLineWidth((self.splitter:isHovered() or self.splitter:isPressed(1)) and splitterWidth or 1)
  if horizontal then
    lg.line(x, self.splitDistance, x + w, self.splitDistance)
  else
    local y1 = y
    if self.side2.class == TabView then
      local tv = self.side2 --[[@as TabView]]
      if #tv.tabs > 0 then
        y1 = y1 + tv:tabBarHeight()
      end
    end
    lg.line(self.splitDistance, y1, self.splitDistance, y + h)
  end
end

return SplitView
