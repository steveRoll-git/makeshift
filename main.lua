local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local treeView = require "ui.treeView"
local sceneEditor = require "ui.sceneEditor"
local spriteEditor = require "ui.spriteEditor"
local tabView = require "ui.tabView"
local images = require "images"
local fonts = require "fonts"

local hexToColor = require "util.hexToColor"

local project = require "project"

local newScene = project.addScene()

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

local editor = sceneEditor(newScene)

local libraryPanel = treeView()

local function resourceItemModels()
  ---@type TreeItemModel[]
  local items = {}
  for _, resource in pairs(project.getResources()) do
    table.insert(items, { text = resource.name })
  end
  return items
end

libraryPanel:setItems(resourceItemModels())

local testTabView = tabView()
testTabView.font = fonts("Inter-Regular.ttf", 14)
testTabView:setTabs {
  {
    text = "Wow a Scene",
    content = editor
  },
  {
    text = "Library",
    content = libraryPanel
  },
  {
    text = "Another Tab",
    content = libraryPanel
  }
}

local uiScene = zap.createScene()

lg.setBackgroundColor(hexToColor(0x181818))

function love.mousemoved(x, y, dx, dy)
  uiScene:setMousePosition(x, y)
end

function love.mousepressed(x, y, btn)
  uiScene:mousePressed(btn)
  if popup and popupRendered and not popup:isInHierarchy(uiScene:getPressedElement()) then
    ClosePopup()
  end
end

function love.mousereleased(x, y, btn)
  uiScene:mouseReleased(btn)
end

function love.wheelmoved(x, y)
  uiScene:wheelMoved(x, y)
end

function love.draw()
  uiScene:begin()
  testTabView:render(0, 0, lg.getDimensions())
  if popup then
    popup:render(popupX, popupY, popupW, popupH)
    popupRendered = true
  end
  uiScene:finish()
end
