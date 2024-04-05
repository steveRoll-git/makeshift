local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local engine = require "engine"

---@class SceneEditor: Zap.ElementClass
---@operator call:SceneEditor
local sceneEditor = zap.elementClass()

function sceneEditor:init()
  self.engine = engine.createEngine()
end

function sceneEditor:render(x, y, w, h)
  lg.setScissor(x, y, w, h)
  lg.push()
  lg.translate(x, y)
  self.engine:draw()
  lg.pop()
  lg.setScissor()
end

return sceneEditor
