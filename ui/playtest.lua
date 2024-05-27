local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local engine = require "engine"

---@class PlaytestElement: Zap.ElementClass
---@operator call:PlaytestElement
local playtest = zap.elementClass()

---@param scene Scene
function playtest:init(scene)
  self.engine = engine.createEngine(scene, true)
end

function playtest:update(dt)
  self.engine:update(dt)
end

function playtest:render(x, y, w, h)
  lg.push()
  lg.translate(x, y)
  self.engine:draw()
  lg.pop()
end

return playtest
