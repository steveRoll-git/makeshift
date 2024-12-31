local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local Button = require "ui.components.button"
local images = require "images"
local clamp = require "util.clamp"
local lerp = require "util.lerp"
local viewTools = require "util.viewTools"
local pushScissor = require "util.scissorStack".pushScissor
local popScissor = require "util.scissorStack".popScissor

local resizeHandleSize = 10

---@class Window.ResizeHandle: Zap.ElementClass
---@operator call:Window.ResizeHandle
local ResizeHandle = zap.elementClass()

---@param w Window
function ResizeHandle:init(w)
  self.window = w
end

function ResizeHandle:getCursor()
  return love.mouse.getSystemCursor("sizenwse")
end

function ResizeHandle:mousePressed(btn)
  if btn == 1 then
    local mx, my = self:getAbsoluteMouse()
    self.offsetX = mx - self.window.x - self.window.width
    self.offsetY = my - self.window.y - self.window.height
  end
end

function ResizeHandle:mouseMoved()
  if self:isPressed(1) then
    local mx, my = self:getAbsoluteMouse()
    self.window.width = mx - self.window.x - self.offsetX
    self.window.height = my - self.window.y - self.offsetY
    self.window:clampSize()
  end
end

---@class Window: Zap.ElementClass
---@field icon love.Image
---@field title string
---@field titleFont love.Font
---@field content Zap.Element
---@field x number
---@field y number
---@field width number
---@field height number
---@field closable boolean
---@field resizable boolean
---@field dockable boolean
---@field focused boolean
---@field animContentView? {progress: number, fromX: number, fromY: number, fromW: number, fromH: number}
---@operator call:Window
local Window = zap.elementClass()

function Window:init()
  self.closeButton = Button()
  self.closeButton.displayMode = "image"
  self.closeButton.image = images["icons/close_18.png"]
  self.closeButton.onClick = function()
    CloseWindow(self)
  end

  self.resizeHandle = ResizeHandle(self)
end

function Window:desiredWidth()
  return self.width
end

function Window:desiredHeight()
  return self.height
end

function Window:titleBarHeight()
  return self.titleFont:getHeight() + 16
end

---Sets the size of the window so that the size of the content will match the provided width and height.
---@param width number
---@param height number
function Window:setContentSize(width, height)
  self.width = width
  self.height = height + self:titleBarHeight()
end

function Window:clampPosition()
  self.x = clamp(self.x, -self.width / 2, lg.getWidth() - self.width / 2)
  self.y = clamp(self.y, 0, lg.getHeight() - self.height / 2)
end

function Window:clampSize()
  self.width = math.max(self.width, 200)
  self.height = math.max(self.height, 200)
end

---Removes this window and creates a new tab with its contents.
---@param tabView TabView
function Window:dockIntoTab(tabView)
  local newTab = tabView:addTab({
    text = self.title,
    icon = self.icon,
    content = self.content,
    closable = self.closable,
    dockable = true,
  })
  newTab.isDragging = true
  newTab.dragStartX = math.min(self.dragX, self.icon:getWidth() + self.titleFont:getWidth(self.title))
  newTab.dragStartY = self.dragY
  newTab.lastUndockW = self.width
  newTab.lastUndockH = self.height
  newTab:setScene(self:getScene())
  newTab:updateDragX()
  local cx, cy, cw, ch = self.content:getView()
  tabView.animContentView = { progress = 0, fromX = cx, fromY = cy, fromW = cw, fromH = ch }
  Tweens:to(tabView.animContentView, 0.3, { progress = 1 })
      :ease("quintout")
      :oncomplete(function()
        tabView.animContentView = nil
      end)
  self:getScene():setPressedElement(newTab, 1)
  RemoveWindow(self)
end

function Window:mousePressed(btn)
  if btn == 1 then
    self.dragging = true
    self.dragX, self.dragY = self:getRelativeMouse()
  end
end

function Window:mouseReleased(btn)
  if btn == 1 and self.dragging then
    self.dragging = false
  end
end

function Window:mouseMoved(x, y, dx, dy)
  if self.dragging then
    local mx, my = self:getAbsoluteMouse()
    self.x = mx - self.dragX
    self.y = my - self.dragY
    if self.dockable then
      for _, tabView in ipairs(GetAllDockableTabViews()) do
        if tabView:isMouseOverTabBar() then
          self:dockIntoTab(tabView)
          return
        end
      end
    end
    self:clampPosition()
  end
end

function Window:keyPressed(key)
  if self.content.class.keyPressed then
    self.content.class.keyPressed(self.content, key)
  end
end

function Window:keyReleased(key)
  if self.content.class.keyReleased then
    self.content.class.keyReleased(self.content, key)
  end
end

function Window:textInput(text)
  if self.content.class.textInput then
    self.content.class.textInput(self.content, text)
  end
end

function Window:render(x, y, w, h)
  local outlineColor = self.focused and CurrentTheme.outlineActive or CurrentTheme.outline

  local cornerRadius = 6
  if self.focused then
    lg.setColor(CurrentTheme.backgroundActive)
  else
    lg.setColor(CurrentTheme.backgroundInactive)
  end
  lg.rectangle("fill", x, y, w, self:titleBarHeight() + cornerRadius, cornerRadius)
  lg.setColor(outlineColor)
  lg.setLineStyle("rough")
  lg.setLineWidth(1)
  lg.rectangle("line", x, y, w, self:titleBarHeight() + cornerRadius, cornerRadius)

  lg.setColor(self.focused and CurrentTheme.foregroundActive or CurrentTheme.foreground)
  local ex = x + 6
  if self.icon then
    lg.draw(self.icon, ex, math.floor(y + self:titleBarHeight() / 2 - self.icon:getHeight() / 2))
    ex = ex + self.icon:getWidth() + 3
  end
  lg.setFont(self.titleFont)
  lg.print(self.title,
    ex,
    math.floor(y + self:titleBarHeight() / 2 - self.titleFont:getHeight() / 2))

  if self.closable then
    self.closeButton:render(viewTools.padding(
      x + w - self:titleBarHeight(),
      y,
      self:titleBarHeight(),
      self:titleBarHeight(),
      1))
  end

  local cx, cy, cw, ch = x, y + self:titleBarHeight(), w, h - self:titleBarHeight()
  if self.animContentView then
    cx = lerp(self.animContentView.fromX, cx, self.animContentView.progress)
    cy = lerp(self.animContentView.fromY, cy, self.animContentView.progress)
    cw = lerp(self.animContentView.fromW, cw, self.animContentView.progress)
    ch = lerp(self.animContentView.fromH, ch, self.animContentView.progress)
  end

  lg.setColor(CurrentTheme.backgroundInactive)
  lg.rectangle("fill", cx, cy, cw, ch)
  pushScissor(cx, cy, cw, ch)
  self.content:render(cx, cy, cw, ch)
  popScissor()

  lg.setColor(outlineColor)
  lg.setLineStyle("rough")
  lg.setLineWidth(1)
  lg.line(
    cx, cy,
    cx, cy + ch,
    cx + cw, cy + ch,
    cx + cw, cy)

  if self.resizable then
    self.resizeHandle:render(x + w, y + h, resizeHandleSize, resizeHandleSize)
  end
end

return Window
