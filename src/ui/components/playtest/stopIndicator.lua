local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local images = require "images"
local lerp = require "util.lerp"
local fontCache = require "util.fontCache"

local icons = {
  error = images["icons/error_stopped_32.png"],
  wait = images["icons/hourglass_32.png"],
}

local messages = {
  error = [[
The game has stopped due to an error.
Click to go to code.]],
  wait = [[
Some code is taking a long time to complete.
Click to go to code.]],
}

local iconSize = 32
local padding = 6
local textPadding = 4
local font = fontCache.get("Inter-Regular.ttf", 14)

---@class StopIndicator: Zap.ElementClass
---@field stopReason "error" | "wait"
---@operator call:StopIndicator
local StopIndicator = zap.elementClass()

---@param playtest Playtest
function StopIndicator:init(playtest)
  self.playtest = playtest
end

function StopIndicator:mouseClicked(btn)
  if btn == 1 then
    if self.stopReason == "error" then
      self.playtest.engine:openErroredCodeEditor()
    elseif self.stopReason == "wait" then
      local editor = OpenResourceTab(self.playtest.engine.loopStuckScript) --[[@as CodeEditor]]
      editor.textEditor:jumpToLine(self.playtest.engine.loopStuckStartLine)
    end
  end
end

function StopIndicator:desiredWidth()
  return iconSize + padding * 2 + (self:isHovered() and textPadding + font:getWidth(messages[self.stopReason]) or 0)
end

function StopIndicator:desiredHeight()
  return iconSize + padding * 2
end

function StopIndicator:render(x, y, w, h)
  lg.setColor(CurrentTheme.backgroundOverlay)
  lg.rectangle("fill", x, y, w, h, 3)
  do
    local r, g, b, a = unpack(CurrentTheme.foregroundActive)
    a = (a or 1) * lerp(0.7, 1, (math.sin(love.timer.getTime() * 4) + 1) / 2)
    lg.setColor(r, g, b, a)
  end
  lg.draw(icons[self.stopReason], x + padding, y + padding)

  if self:isHovered() then
    lg.setColor(CurrentTheme.foregroundActive)
    lg.setFont(font)
    lg.print(messages[self.stopReason], x + padding + iconSize + textPadding, y + h / 2 - font:getHeight())
  end
end

return StopIndicator
