local love = love
local lg = love.graphics

require "util.windowsDarkMode"
local images = require "images"

love.window.maximize()

local zap = require "lib.zap.zap"
local treeView = require "ui.treeView"
local sceneEditor = require "ui.sceneEditor"
local tabView = require "ui.tabView"
local spriteEditor = require "ui.spriteEditor"
local fonts = require "fonts"
local hexToColor = require "util.hexToColor"
local project = require "project"

---@class Zap.ElementClass
---@field mouseDoubleClicked fun(self: Zap.Element, button: any)

---@type Zap.Element?
local popup
local popupRendered = false
---@type number, number, number, number
local popupX, popupY, popupW, popupH

function GetPopup()
  return popup
end

---Opens `element` as a popup.<br>
---Popups disappear when the mouse clicks anywhere outside of them.
---@param element Zap.Element
---@param x number
---@param y number
---@param w number
---@param h number
function OpenPopup(element, x, y, w, h)
  popup = element
  popupX = x
  popupY = y
  popupW = w
  popupH = h
  popupRendered = false
end

---Closes the currently open popup element.
function ClosePopup()
  popup = nil
  popupRendered = false
end

local libraryPanel = treeView()

local function resourceItemModels()
  ---@type TreeItemModel[]
  local items = {}
  for _, resource in pairs(project.getResources()) do
    table.insert(items, {
      text = resource.name,
      icon = resource.type == "scene" and images["icons/scene_24.png"],
      onClick = function()
        OpenResourceTab(resource)
      end
    })
  end
  return items
end

libraryPanel:setItems(resourceItemModels())

local mainTabView = tabView()
mainTabView.font = fonts("Inter-Regular.ttf", 14)
mainTabView:setTabs {
  {
    text = "Library",
    content = libraryPanel
  },
}

---Adds a new tab to the main tabView.
---@param tab TabModel
function AddNewTab(tab)
  mainTabView:addTab(tab)
end

---Opens a new tab to edit this resource.
---@param r Resource
function OpenResourceTab(r)
  if r.type == "scene" then
    AddNewTab({
      text = r.name,
      content = sceneEditor(r)
    })
  elseif r.type == "objectData" then
    local e = spriteEditor()
    e.editingObjectData = r --[[@as ObjectData]]
    AddNewTab({
      text = r.name,
      content = e
    })
  end
end

local uiScene = zap.createScene()

local lastPressTime
local lastPressButton
local lastPressedElement
-- The maximum time in between clicks that will fire a double click.
local doubleClickTime = 0.2

lg.setBackgroundColor(hexToColor(0x181818))

function love.mousemoved(x, y, dx, dy)
  uiScene:setMousePosition(x, y)
end

function love.mousepressed(x, y, btn)
  uiScene:mousePressed(btn)
  local pressedElement = uiScene:getPressedElement()
  if btn == lastPressButton and
      love.timer.getTime() - lastPressTime <= doubleClickTime and
      pressedElement == lastPressedElement and
      pressedElement.class.mouseDoubleClicked then
    pressedElement.class.mouseDoubleClicked(pressedElement, btn)
  end
  if popup and popupRendered and not popup:isInHierarchy(pressedElement) then
    ClosePopup()
  end
  lastPressTime = love.timer.getTime()
  lastPressButton = btn
  lastPressedElement = pressedElement
end

function love.mousereleased(x, y, btn)
  uiScene:mouseReleased(btn)
end

function love.wheelmoved(x, y)
  uiScene:wheelMoved(x, y)
end

function love.draw()
  uiScene:begin()
  mainTabView:render(0, 0, lg.getDimensions())
  if popup then
    popup:render(popupX, popupY, popupW, popupH)
    popupRendered = true
  end
  uiScene:finish()
end

function love.quit()
  for _, t in ipairs(mainTabView.tabs) do
    if t.content.class == sceneEditor then
      (t.content --[[@as SceneEditor]]):writeToScene()
    end
  end
  project.saveProject()
end
