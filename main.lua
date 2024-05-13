local IS_DEBUG = os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" and arg[2] == "debug"
if IS_DEBUG then
  require("lldebugger").start()

  function love.errorhandler(msg)
    error(msg, 2)
  end
end

local love = love
local lg = love.graphics

require "util.windowsDarkMode"

love.window.maximize()

love.keyboard.setKeyRepeat(true)

local zap = require "lib.zap.zap"
local treeView = require "ui.treeView"
local sceneEditor = require "ui.sceneEditor"
local tabView = require "ui.tabView"
local spriteEditor = require "ui.spriteEditor"
local textEditor = require "ui.textEditor"
local fonts = require "fonts"
local hexToColor = require "util.hexToColor"
local project = require "project"
local images = require "images"

---@class Zap.ElementClass
---@field mouseDoubleClicked fun(self: Zap.Element, button: any)
---@field keyPressed fun(self: Zap.Element, key: string)
---@field keyReleased fun(self: Zap.Element, key: string)
---@field popupClosed fun(self: Zap.Element)
---@field textInput fun(self: Zap.Element, text: string)
---@field getCursor fun(self: Zap.Element): love.Cursor

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
  if popup and popup.class.popupClosed then
    popup.class.popupClosed(popup)
  end
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
    icon = images["icons/library_24.png"],
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
      icon = images["icons/scene_24.png"],
      content = sceneEditor(r),
      closable = true,
    })
  elseif r.type == "objectData" then
    local e = spriteEditor()
    e.editingObjectData = r --[[@as ObjectData]]
    AddNewTab({
      text = r.name,
      content = e,
      closable = true,
    })
  end
end

---Returns the element that currently has keyboard focus.
---@return Zap.Element
local function getFocusedElement()
  if popup then
    return popup
  else
    return mainTabView.activeTab.content
  end
end

local uiScene = zap.createScene()

local lastPressTime
local lastPressButton
local lastPressedElement
-- The maximum time in between clicks that will fire a double click.
local doubleClickTime = 0.2

lg.setBackgroundColor(hexToColor(0x181818))

local function updateCursor()
  local cursorToSet
  local hovered = uiScene:getHoveredElements()
  for i = #hovered, 1, -1 do
    local e = hovered[i]
    if e.class.getCursor then
      cursorToSet = e.class.getCursor(e)
    end
  end
  love.mouse.setCursor(cursorToSet)
end

function love.mousemoved(x, y, dx, dy)
  uiScene:moveMouse(x, y, dx, dy)
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

function love.keypressed(key)
  local focused = getFocusedElement()
  if focused.class.keyPressed then
    focused.class.keyPressed(focused, key)
  end
end

function love.keyreleased(key)
  local focused = getFocusedElement()
  if focused.class.keyReleased then
    focused.class.keyReleased(focused, key)
  end
end

function love.textinput(text)
  local focused = getFocusedElement()
  if focused.class.textInput then
    focused.class.textInput(focused, text)
  end
end

function love.update(dt)
  updateCursor()
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
    if t.content["onClose"] then
      ---@diagnostic disable-next-line: undefined-field
      t.content:onClose()
    end
  end
  project.saveProject()
end
