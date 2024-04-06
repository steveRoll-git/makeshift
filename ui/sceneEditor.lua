local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local engine = require "engine"

---@class SceneEditor: Zap.ElementClass
---@field selectedObject Object?
---@operator call:SceneEditor
local sceneEditor = zap.elementClass()

function sceneEditor:init(scene)
  self.engine = engine.createEngine(scene)
end

function sceneEditor:mousePressed(button)
  self.selectedObject = nil
  local mx, my = self:getRelativeMouse()
  for i = #self.engine.objects.list, 1, -1 do
    ---@type Object
    local obj = self.engine.objects.list[i]
    if mx >= obj.x and my >= obj.y and mx < obj.x + obj.image:getWidth() and my < obj.y + obj.image:getHeight() then
      self.selectedObject = obj
      break
    end
  end
end

function sceneEditor:render(x, y, w, h)
  lg.setScissor(x, y, w, h)
  lg.push()
  lg.translate(x, y)
  self.engine:draw()
  if self.selectedObject then
    lg.setColor(1, 1, 1, 0.5)
    lg.setLineWidth(1)
    lg.rectangle("line",
      self.selectedObject.x - 1,
      self.selectedObject.y - 1,
      self.selectedObject.image:getWidth() + 2,
      self.selectedObject.image:getHeight() + 2)
  end
  lg.pop()
  lg.setScissor()
end

return sceneEditor
