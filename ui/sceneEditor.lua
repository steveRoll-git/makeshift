local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local engine = require "engine"
local toolbar = require "ui.toolbar"
local images = require "images"

---@class SceneEditor: Zap.ElementClass
---@field selectedObject Object?
---@field draggingObject {object: Object, offsetX: number, offsetY: number}
---@operator call:SceneEditor
local sceneEditor = zap.elementClass()

function sceneEditor:init(scene)
  self.engine = engine.createEngine(scene)

  self.toolbar = toolbar()
  self.toolbar:setItems {
    {
      text = "New Object",
      image = images["icons/add_box_24.png"],
      action = function()

      end
    }
  }
end

function sceneEditor:mousePressed(button)
  self.selectedObject = nil
  local mx, my = self:getRelativeMouse()
  for i = #self.engine.objects.list, 1, -1 do
    ---@type Object
    local obj = self.engine.objects.list[i]
    if mx >= obj.x and my >= obj.y and mx < obj.x + obj.image:getWidth() and my < obj.y + obj.image:getHeight() then
      self.selectedObject = obj
      self.draggingObject = {
        object = obj,
        offsetX = obj.x - mx,
        offsetY = obj.y - my,
      }
      break
    end
  end
end

function sceneEditor:mouseReleased(button)
  if self.draggingObject then
    self.draggingObject = nil
  end
end

function sceneEditor:mouseMoved(x, y)
  local mx, my = self:getRelativeMouse()
  if self.draggingObject then
    self.draggingObject.object.x = mx + self.draggingObject.offsetX
    self.draggingObject.object.y = my + self.draggingObject.offsetY
  end
end

function sceneEditor:render(x, y, w, h)
  local toolbarH = self.toolbar:desiredHeight()
  self.toolbar:render(x, y, w, toolbarH)

  y = y + toolbarH
  h = h - toolbarH
  lg.setScissor(x, y, w, h)
  lg.push()
  lg.translate(x, y)
  self.engine:draw()
  if self.selectedObject then
    lg.setColor(1, 1, 1, 0.5)
    lg.setLineWidth(1)
    lg.rectangle("line",
      self.selectedObject.x,
      self.selectedObject.y,
      self.selectedObject.image:getWidth(),
      self.selectedObject.image:getHeight())
  end
  lg.pop()
  lg.setScissor()
end

return sceneEditor
