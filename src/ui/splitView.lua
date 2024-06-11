local love = love
local lg = love.graphics

local hexToColor = require "util.hexToColor"
local zap = require "lib.zap.zap"
local tabView = require "ui.tabView"
local clamp = require "util.clamp"
local pushScissor = require "util.scissorStack".pushScissor
local popScissor = require "util.scissorStack".popScissor

local splitterWidth = 6

local minimumSplitSize = 200

---@class SplitViewSplitter: Zap.ElementClass
---@operator call:SplitViewSplitter
local splitter = zap.elementClass()

---@param splitView SplitView
function splitter:init(splitView)
  self.splitView = splitView
end

function splitter:getCursor()
  return love.mouse.getSystemCursor(self.splitView.orientation == "horizontal" and "sizens" or "sizewe")
end

function splitter:mousePressed(button)
  if button == 1 then
    self.offsetX, self.offsetY = self:getRelativeMouse()
  end
end

function splitter:mouseMoved()
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
---@field orientation "horizontal" | "vertical"
---@field splitDistance number
---@operator call:SplitView
local splitView = zap.elementClass()

function splitView:init()
  self.splitter = splitter(self)
end

function splitView:clampSplitDistance()
  local _, _, w, h = self:getView()
  self.splitDistance = clamp(
    self.splitDistance,
    minimumSplitSize,
    (self.orientation == "horizontal" and h or w) - minimumSplitSize)
end

function splitView:resized(w, h, prevW, prevH)
  self:clampSplitDistance()
end

function splitView:render(x, y, w, h)
  local horizontal = self.orientation == "horizontal"
  local vertical = self.orientation == "vertical"

  assert(horizontal or vertical, "no orientation set for this splitter!")

  local x1 = x
  local y1 = y
  local w1 = horizontal and w or self.splitDistance
  local h1 = vertical and h or self.splitDistance
  pushScissor(x1, y1, w1, h1)
  self.side1:render(x1, y1, w1, h1)
  popScissor()

  local x2 = horizontal and x or x + self.splitDistance
  local y2 = vertical and y or y + self.splitDistance
  local w2 = horizontal and w or w - self.splitDistance
  local h2 = vertical and h or h - self.splitDistance
  pushScissor(x2, y2, w2, h2)
  self.side2:render(x2, y2, w2, h2)
  popScissor()

  self.splitter:render(
    horizontal and x or x + self.splitDistance - splitterWidth / 2,
    vertical and y or y + self.splitDistance - splitterWidth / 2,
    horizontal and w or splitterWidth,
    vertical and h or splitterWidth
  )

  lg.setColor(hexToColor(0x2b2b2b))
  lg.setLineStyle("rough")
  lg.setLineWidth((self.splitter:isHovered() or self.splitter:isPressed(1)) and splitterWidth or 1)
  if horizontal then
    lg.line(x, self.splitDistance, x + w, self.splitDistance)
  else
    local y1 = y
    if self.side2.class == tabView then
      local tv = self.side2 --[[@as TabView]]
      if #tv.tabs > 0 then
        y1 = y1 + tv:tabBarHeight()
      end
    end
    lg.line(self.splitDistance, y1, self.splitDistance, y + h)
  end
end

return splitView
