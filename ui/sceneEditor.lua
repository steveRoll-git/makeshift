local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local engine = require "engine"
local toolbar = require "ui.toolbar"
local images = require "images"
local hexToColor = require "util.hexToColor"

local zoomValues = { 0.25, 1 / 3, 0.5, 1, 2, 3, 4, 5, 6, 8, 12, 16, 24, 32, 48, 64 }

---@class SceneView: Zap.ElementClass
---@field editor SceneEditor
---@field engine Engine
---@field selectedObject Object?
---@field draggingObject {object: Object, offsetX: number, offsetY: number}
---@operator call:SceneView
local sceneView = zap.elementClass()

---@param editor SceneEditor
function sceneView:init(editor)
  self.editor = editor
  self.engine = editor.engine
  self.gridSize = 100
  self.panX, self.panY = 0, 0
  self.zoom = 1
  self.viewTransform = love.math.newTransform()
end

---Updates `viewTransform` according to the current values of `panX`, `panY` and `zoom`.
function sceneView:updateViewTransform()
  self.viewTransform
      :reset()
      :scale(self.zoom, self.zoom)
      :translate(
        -self.panX,
        -self.panY)
end

function sceneView:mousePressed(button)
  if button == 1 then
    self.selectedObject = nil
    local mx, my = self:getRelativeMouse()
    mx, my = self.viewTransform:inverseTransformPoint(mx, my)
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
  elseif button == 3 then
    self.panning = true
    self.panStart = {
      worldX = self.panX,
      worldY = self.panY
    }
    self.panStart.screenX, self.panStart.screenY = self:getRelativeMouse()
  end
end

function sceneView:mouseReleased(button)
  if button == 1 and self.draggingObject then
    self.draggingObject = nil
  elseif button == 3 then
    self.panning = false
  end
end

function sceneView:mouseMoved(x, y)
  local mx, my = self:getRelativeMouse()
  if self.draggingObject then
    mx, my = self.viewTransform:inverseTransformPoint(mx, my)
    self.draggingObject.object.x = mx + self.draggingObject.offsetX
    self.draggingObject.object.y = my + self.draggingObject.offsetY
  elseif self.panning then
    local dx, dy = mx - self.panStart.screenX, my - self.panStart.screenY
    self.panX = self.panStart.worldX - dx / self.zoom
    self.panY = self.panStart.worldY - dy / self.zoom
  end
end

function sceneView:wheelMoved(x, y)
  local newZoom = self.zoom
  if y > 0 then
    for i = 1, #zoomValues do
      if zoomValues[i] > self.zoom then
        newZoom = zoomValues[i]
        break
      end
    end
  elseif y < 0 then
    for i = #zoomValues, 1, -1 do
      if zoomValues[i] < self.zoom then
        newZoom = zoomValues[i]
        break
      end
    end
  end
  if newZoom ~= self.zoom then
    local mx, my = self:getRelativeMouse()
    local prevPanX, prevPanY = self.panX, self.panY
    local prevWorldX, prevWorldY = self.viewTransform:inverseTransformPoint(mx, my)
    local diffX, diffY = (prevWorldX - prevPanX) * self.zoom / newZoom, (prevWorldY - prevPanY) * self.zoom / newZoom

    self.zoom = newZoom

    self.panX, self.panY = prevWorldX - diffX, prevWorldY - diffY

    if self.zoom <= 1 then
      self.panX, self.panY = math.floor(self.panX), math.floor(self.panY)
    end
  end
end

function sceneView:render(x, y, w, h)
  lg.setScissor(x, y, w, h)
  lg.push()
  lg.translate(x, y)
  self:updateViewTransform()
  lg.applyTransform(self.viewTransform)

  lg.setLineStyle("rough")
  lg.setColor(1, 1, 1, 0.1)
  for lineX = math.ceil(self.panX / self.gridSize) * self.gridSize, self.panX + w / self.zoom, self.gridSize do
    if lineX == 0 then
      lg.setLineWidth(3)
    else
      lg.setLineWidth(1)
    end
    lg.line(lineX, self.panY, lineX, self.panY + h / self.zoom)
  end
  for lineY = math.ceil(self.panY / self.gridSize) * self.gridSize, self.panY + h / self.zoom, self.gridSize do
    if lineY == 0 then
      lg.setLineWidth(3)
    else
      lg.setLineWidth(1)
    end
    lg.line(self.panX, lineY, self.panX + w / self.zoom, lineY)
  end

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

---@class SceneEditor: Zap.ElementClass
---@operator call:SceneEditor
local sceneEditor = zap.elementClass()

function sceneEditor:init(scene)
  self.engine = engine.createEngine(scene)

  self.sceneView = sceneView(self)

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

function sceneEditor:render(x, y, w, h)
  local toolbarH = self.toolbar:desiredHeight()
  self.toolbar:render(x, y, w, toolbarH)

  self.sceneView:render(x, y + toolbarH, w, h - toolbarH)

  lg.setColor(hexToColor(0x2b2b2b))
  lg.setLineStyle("rough")
  lg.setLineWidth(1)
  lg.line(x, y + toolbarH, x + w, y + toolbarH)
end

return sceneEditor
