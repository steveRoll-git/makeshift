local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local engine = require "engine"
local stopIndicator = require "ui.playtest.stopIndicator"

---@class PlaytestElement: Zap.ElementClass
---@operator call:PlaytestElement
local playtest = zap.elementClass()

---@param scene Scene
function playtest:init(scene)
  self.engine = engine.createEngine(scene, true)
  self.stopIndicator = stopIndicator(self)
end

function playtest:update(dt)
  self.engine:update(dt)
end

function playtest:render(x, y, w, h)
  lg.push()
  lg.translate(x, y)
  self.engine:draw()
  lg.pop()

  local stopReason
  if self.engine.errorMessage then
    stopReason = "error"
  elseif self.engine.loopStuckScript then
    stopReason = "wait"
  end
  if stopReason then
    self.stopIndicator.stopReason = stopReason
    self.stopIndicator:render(x + 12, y + 12, self.stopIndicator:desiredWidth(), self.stopIndicator:desiredHeight())
  end
end

return playtest
