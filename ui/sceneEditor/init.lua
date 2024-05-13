local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local engine = require "engine"
local toolbar = require "ui.toolbar"
local images = require "images"
local hexToColor = require "util.hexToColor"
local spriteEditor = require "ui.spriteEditor"
local zoomSlider = require "ui.zoomSlider"
local propertiesPanel = require "ui.sceneEditor.propertiesPanel"
local codeEditor = require "ui.codeEditor"

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
  if self.spriteEditor then
    self.viewTransform
        :reset()
        :scale(self.spriteEditor.zoom, self.spriteEditor.zoom)
        :translate(
          self.spriteEditor.panX / self.spriteEditor.zoom - self.selectedObject.x,
          self.spriteEditor.panY / self.spriteEditor.zoom - self.selectedObject.y)
  else
    self.viewTransform
        :reset()
        :scale(self.zoom, self.zoom)
        :translate(-self.panX, -self.panY)
  end
end

function sceneView:startCreatingObject()
  self.creatingObject = true
  self.creationX = nil
  self.creationY = nil
  love.mouse.setCursor(love.mouse.getSystemCursor("crosshair"))
end

---Opens an embedded sprite editor.
---@param object Object
function sceneView:openSpriteEditor(object)
  self.spriteEditor = spriteEditor(self)
  self.spriteEditor.editingObjectData = object.data
  self.spriteEditor.panX, self.spriteEditor.panY = self.viewTransform:transformPoint(object.x, object.y)
  self.spriteEditor.zoom = self.zoom
end

function sceneView:exitSpriteEditor()
  self.zoom = self.spriteEditor.zoom
  self.panX = -(self.spriteEditor.panX / self.spriteEditor.zoom - self.selectedObject.x)
  self.panY = -(self.spriteEditor.panY / self.spriteEditor.zoom - self.selectedObject.y)
  self.spriteEditor = nil
end

---@param obj Object?
function sceneView:selectObject(obj)
  self.selectedObject = obj
  if obj then
    self.editor.propertiesPanel:setObject(obj)
  end
end

function sceneView:mousePressed(button)
  if button == 1 then
    if self.creatingObject then
      self.creationX, self.creationY = self.viewTransform:inverseTransformPoint(self:getRelativeMouse())
    else
      self:selectObject(nil)
      local mx, my = self:getRelativeMouse()
      mx, my = self.viewTransform:inverseTransformPoint(mx, my)
      for i = #self.engine.objects.list, 1, -1 do
        ---@type Object
        local obj = self.engine.objects.list[i]
        if mx >= obj.x and my >= obj.y and mx < obj.x + obj.data.w and my < obj.y + obj.data.h then
          self:selectObject(obj)
          self.draggingObject = {
            object = obj,
            offsetX = obj.x - mx,
            offsetY = obj.y - my,
          }
          break
        end
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
  if button == 1 then
    if self.creatingObject then
      local mx, my = self.viewTransform:inverseTransformPoint(self:getRelativeMouse())
      local x = math.min(mx, self.creationX)
      local y = math.min(my, self.creationY)
      local w = math.floor(math.abs(mx - self.creationX))
      local h = math.floor(math.abs(my - self.creationY))

      ---@type ObjectData
      local newData = {
        type = "objectData",
        w = w,
        h = h,
        frames = {},
        script = { type = "script", code = "" },
      }
      ---@type Object
      local newObject = {
        x = x,
        y = y,
        data = newData
      }
      self.engine.objects:add(newObject)
      self:openSpriteEditor(newObject)
      self.spriteEditor:addFrame()
      self:selectObject(newObject)

      self.creatingObject = false
      love.mouse.setCursor()
    elseif self.draggingObject then
      self.draggingObject = nil
    end
  elseif button == 3 then
    self.panning = false
  end
end

function sceneView:mouseMoved(x, y)
  if self.draggingObject then
    x, y = self.viewTransform:inverseTransformPoint(x, y)
    self.draggingObject.object.x = x + self.draggingObject.offsetX
    self.draggingObject.object.y = y + self.draggingObject.offsetY
  elseif self.panning then
    local dx, dy = x - self.panStart.screenX, y - self.panStart.screenY
    self.panX = self.panStart.worldX - dx / self.zoom
    self.panY = self.panStart.worldY - dy / self.zoom
  end
end

function sceneView:mouseDoubleClicked(button)
  if button == 1 and self.selectedObject then
    self:openSpriteEditor(self.selectedObject)
    self.spriteEditor:updateTransparencyQuad()
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
    local prevWorldX, prevWorldY = self.viewTransform:inverseTransformPoint(self:getRelativeMouse())
    local diffX = (prevWorldX - self.panX) * self.zoom / newZoom
    local diffY = (prevWorldY - self.panY) * self.zoom / newZoom

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
  lg.push()
  lg.applyTransform(self.viewTransform)

  do
    local x1, y1 = self.viewTransform:inverseTransformPoint(0, 0)
    local x2, y2 = self.viewTransform:inverseTransformPoint(w, h)
    lg.setLineStyle("rough")
    lg.setColor(1, 1, 1, 0.1)
    for lineX = math.ceil(x1 / self.gridSize) * self.gridSize, x2, self.gridSize do
      if lineX == 0 then
        lg.setLineWidth(3)
      else
        lg.setLineWidth(1)
      end
      lg.line(lineX, y1, lineX, y2)
    end
    for lineY = math.ceil(y1 / self.gridSize) * self.gridSize, y2, self.gridSize do
      if lineY == 0 then
        lg.setLineWidth(3)
      else
        lg.setLineWidth(1)
      end
      lg.line(x1, lineY, x2, lineY)
    end
  end

  self.engine:draw()

  if self.selectedObject then
    lg.setColor(1, 1, 1, 0.5)
    lg.setLineWidth(1)
    lg.rectangle("line",
      self.selectedObject.x,
      self.selectedObject.y,
      self.selectedObject.data.frames[1].image:getWidth(),
      self.selectedObject.data.frames[1].image:getHeight())
  end

  lg.pop()

  if self.creatingObject and self.creationX then
    local x1, y1 = self.viewTransform:transformPoint(self.creationX, self.creationY)
    local x2, y2 = self:getRelativeMouse()
    lg.setColor(1, 1, 1, 0.2)
    lg.setLineWidth(2)
    lg.setLineStyle("rough")
    lg.rectangle("line", x1, y1, x2 - x1, y2 - y1)
  end

  lg.pop()
  lg.setScissor()
end

---@class SceneEditor: Zap.ElementClass
---@operator call:SceneEditor
local sceneEditor = zap.elementClass()

---@param scene Scene
function sceneEditor:init(scene)
  self.originalScene = scene
  self.engine = engine.createEngine(scene)

  self.sceneView = sceneView(self)

  self.toolbar = toolbar()
  self.toolbar:setItems {
    {
      text = "New Object",
      image = images["icons/add_box_24.png"],
      action = function()
        self.sceneView:startCreatingObject()
      end
    }
  }

  self.zoomSlider = zoomSlider()
  self.zoomSlider.targetTable = self.sceneView

  self.propertiesPanel = propertiesPanel()
end

function sceneEditor:writeToScene()
  self.originalScene.objects = {}
  for _, o in ipairs(self.engine.objects.list) do
    table.insert(self.originalScene.objects, o)
  end
end

function sceneEditor:onClose()
  self:writeToScene()
end

function sceneEditor:keyPressed(key)
  if key == "f9" and self.sceneView.selectedObject then
    AddNewTab({
      text = "Code Editor",
      icon = images["icons/code_24.png"],
      content = codeEditor(self.sceneView.selectedObject.data.script),
      closable = true
    })
  end
end

function sceneEditor:render(x, y, w, h)
  local toolbar = self.toolbar
  if self.sceneView.spriteEditor then
    toolbar = self.sceneView.spriteEditor.topToolbar
  end
  local toolbarH = toolbar:desiredHeight()

  self.sceneView:render(x, y + toolbarH, w, h - toolbarH)
  if self.sceneView.spriteEditor then
    self.sceneView.spriteEditor:render(x, y + toolbarH, w, h - toolbarH)
  end

  toolbar:render(x, y, w, toolbarH)

  if not self.sceneView.spriteEditor then
    local sliderW, sliderH = self.zoomSlider:desiredWidth() + 6, self.zoomSlider:desiredHeight() + 3
    self.zoomSlider:render(x + w - sliderW, y + h - sliderH, sliderW, sliderH)
  end

  if self.sceneView.selectedObject then
    local pw, ph = 240, 200
    local margin = 4
    self.propertiesPanel:render(x + margin, y + h - ph - margin, pw, ph)
  end
end

return sceneEditor
