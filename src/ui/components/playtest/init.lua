local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local engine = require "engine"
local StopIndicator = require "ui.components.playtest.stopIndicator"

---@class Playtest: Zap.ElementClass
---@operator call:Playtest
local Playtest = zap.elementClass()

---@param scene Scene
function Playtest:init(scene)
  self.engine = engine.createEngine(scene, true)
  self.stopIndicator = StopIndicator(self)
end

function Playtest:update(dt)
  self.engine:update(dt)
end

function Playtest:render(x, y, w, h)
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

return Playtest
