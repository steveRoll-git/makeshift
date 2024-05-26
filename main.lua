io.stdout:setvbuf("no")

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
local fonts = require "fonts"
local hexToColor = require "util.hexToColor"
local project = require "project"
local images = require "images"
local orderedSet = require "util.orderedSet"
local window = require "ui.window"
local splitView = require "ui.splitView"
local playtest = require "ui.playtest"

require "util.scissorStack"

local uiScene = zap.createScene()

---@class Zap.ElementClass
---@field mouseDoubleClicked fun(self: Zap.Element, button: any)
---@field keyPressed fun(self: Zap.Element, key: string)
---@field keyReleased fun(self: Zap.Element, key: string)
---@field popupClosed fun(self: Zap.Element)
---@field textInput fun(self: Zap.Element, text: string)
---@field getCursor fun(self: Zap.Element): love.Cursor
---@field saveResource fun(self: Zap.Element)

---An Element that edits a certain resource.
---@class ResourceEditor: Zap.ElementClass
---@field resourceId fun(self: Zap.Element): string

local popups = orderedSet.new()
---@type table<Zap.Element, number[]>
local popupViews = {}
setmetatable(popupViews, { __mode = 'k' })

---Opens `element` as a popup.<br>
---Popups disappear when the mouse clicks anywhere outside of them.
---@param element Zap.Element
---@param x number
---@param y number
---@param w number
---@param h number
function OpenPopup(element, x, y, w, h)
  popups:add(element)
  popupViews[element] = { x, y, w, h }
end

---@param popup Zap.Element
function ClosePopup(popup)
  assert(popups:has(popup), "Tried to close a popup that isn't open")
  if popup and popup.class.popupClosed then
    popup.class.popupClosed(popup)
  end
  popups:remove(popup)
  popupViews[popup] = nil
end

function CloseAllPopups()
  for i = popups:getCount(), 1, -1 do
    if uiScene:isElementRendered(popups:itemAt(i)) then
      ClosePopup(popups:itemAt(i))
    end
  end
end

---Returns whether this element is a popup that's currently open.
---@param popup Zap.Element
---@return boolean
function IsPopupOpen(popup)
  return popups:has(popup)
end

local windows = orderedSet.new()

---@type Window?
local focusedWindow

---@param w Window?
function SetFocusedWindow(w)
  if focusedWindow then
    focusedWindow.focused = false
  end
  focusedWindow = w
  if w then
    w.focused = true
    if windows:getIndex(w) ~= windows:getCount() then
      windows:remove(w)
      windows:add(w)
    end
  end
end

---@param w Window
function AddWindow(w)
  windows:add(w)
  SetFocusedWindow(w)
end

---Removes a window without calling its `saveResource` callback.
---@param w Window
function RemoveWindow(w)
  windows:remove(w)
end

---@param w Window
function CloseWindow(w)
  if w.content.class.saveResource then
    w.content.class.saveResource(w.content)
  end
  RemoveWindow(w)
end

local libraryPanel = treeView()

local function resourceItemModels()
  ---@type TreeItemModel[]
  local items = {}
  for _, resource in pairs(project.currentProject.resources) do
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

local explorerTabView = tabView()
explorerTabView.font = fonts("Inter-Regular.ttf", 14)
explorerTabView:setTabs {
  {
    text = "Library",
    icon = images["icons/library_24.png"],
    content = libraryPanel,
  },
}

local mainTabView = tabView()
mainTabView.font = fonts("Inter-Regular.ttf", 14)

local testSplitView = splitView()
testSplitView.orientation = "vertical"
testSplitView.side1 = explorerTabView
testSplitView.side2 = mainTabView
testSplitView.splitDistance = 200

---Adds a new tab to the main tabView.
---@param tab TabModel
function AddNewTab(tab)
  mainTabView:addTab(tab)
end

---Opens a new tab to edit this resource.
---@param r Resource
function OpenResourceTab(r)
  if FocusResourceEditor(r.id) then
    return
  end
  if r.type == "scene" then
    AddNewTab({
      text = r.name,
      icon = images["icons/scene_24.png"],
      content = sceneEditor(r),
      closable = true,
      dockable = true,
    })
  elseif r.type == "objectData" then
    local e = spriteEditor()
    e.editingObjectData = r --[[@as ObjectData]]
    AddNewTab({
      text = r.name,
      content = e,
      closable = true,
      dockable = true,
    })
  end
end

---Returns whether `element` is an editor of the resource with this ID.
---@param element Zap.Element
---@param id string
---@return boolean
local function isResourceEditor(element, id)
  local class = element.class --[[@as ResourceEditor]]
  return class.resourceId and class.resourceId(element) == id
end

---Searches for a tab or window that is editing the resource with this ID, and focuses it if it's found.
---@param id string
---@return boolean found Whether the tab or window that is editing this resource was found and focused.
function FocusResourceEditor(id)
  for _, tView in ipairs(GetAllDockableTabViews()) do
    for _, tab in ipairs(tView.tabs) do
      if isResourceEditor(tab.content, id) then
        tView:setActiveTab(tab)
        return true
      end
    end
  end
  for _, w in ipairs(windows.list) do
    ---@cast w Window
    if isResourceEditor(w.content, id) then
      SetFocusedWindow(w)
      return true
    end
  end
  return false
end

---Returns all the dockable tabviews currently on screen.
---@return TabView[]
function GetAllDockableTabViews()
  return { mainTabView }
end

---Returns the element that currently has keyboard focus.
---@return Zap.Element?
local function getFocusedElement()
  if popups:getCount() > 0 then
    return popups:last()
  elseif focusedWindow then
    return focusedWindow
  elseif mainTabView.activeTab then
    return mainTabView.activeTab.content
  end
end

---Calls the `saveResource` method for all currently open editors.
local function saveAllOpenResourceEditors()
  for _, t in ipairs(mainTabView.tabs) do
    if t.content.class.saveResource then
      t.content.class.saveResource(t.content)
    end
  end
  for _, w in ipairs(windows.list) do
    ---@cast w Window
    if w.content.class.saveResource then
      w.content.class.saveResource(w.content)
    end
  end
end

local function runPlaytest()
  saveAllOpenResourceEditors()

  local playtestWindow = window()
  playtestWindow.titleFont = fonts("Inter-Regular.ttf", 14)
  playtestWindow.title = "Playtest"
  playtestWindow.icon = images["icons/game_24.png"]
  playtestWindow:setContentSize(
    project.currentProject.windowWidth,
    project.currentProject.windowHeight
  )
  playtestWindow.x = math.floor(lg.getWidth() / 2 - playtestWindow.width / 2)
  playtestWindow.y = math.floor(lg.getHeight() / 2 - playtestWindow.height / 2)
  playtestWindow.closable = true
  playtestWindow.content = playtest(project.currentProject.resources[project.currentProject.initialSceneId])

  AddWindow(playtestWindow)
end

local lastPressTime
local lastPressButton
local lastPressedElement
-- The maximum time in between clicks that will fire a double click.
local doubleClickTime = 0.2

lg.setBackgroundColor(hexToColor(0x181818))

local function updateCursor()
  local cursorToSet
  local pressedElement = uiScene:getPressedElement()
  if pressedElement and pressedElement.class.getCursor then
    cursorToSet = pressedElement.class.getCursor(pressedElement)
  else
    local hovered = uiScene:getHoveredElements()
    for i = #hovered, 1, -1 do
      local e = hovered[i]
      if e.class.getCursor then
        cursorToSet = e.class.getCursor(e)
      end
    end
  end
  love.mouse.setCursor(cursorToSet)
end

---Called just before the element's `mousePressed` event in order to close popups if needed
---@param pressedElement Zap.Element?
local function beforeMousePress(pressedElement)
  if not pressedElement or not IsPopupOpen(pressedElement:getRoot()) then
    CloseAllPopups()
  else
    local index = popups:getIndex(pressedElement:getRoot())
    for i = popups:getCount(), index + 1, -1 do
      if uiScene:isElementRendered(popups:itemAt(i)) then
        ClosePopup(popups:itemAt(i))
      end
    end
  end
end

function love.mousemoved(x, y, dx, dy)
  uiScene:moveMouse(x, y, dx, dy)
end

function love.mousepressed(x, y, btn)
  uiScene:mousePressed(btn, beforeMousePress)
  local pressedElement = uiScene:getPressedElement()

  if btn == lastPressButton and
      love.timer.getTime() - lastPressTime <= doubleClickTime and
      pressedElement == lastPressedElement and
      pressedElement.class.mouseDoubleClicked then
    pressedElement.class.mouseDoubleClicked(pressedElement, btn)
  end

  if pressedElement:getRoot().class == window then
    SetFocusedWindow(pressedElement:getRoot() --[[@as Window]])
  else
    SetFocusedWindow(nil)
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
  if key == "f5" then
    runPlaytest()
  else
    local focused = getFocusedElement()
    if focused and focused.class.keyPressed then
      focused.class.keyPressed(focused, key)
    end
  end
end

function love.keyreleased(key)
  local focused = getFocusedElement()
  if focused and focused.class.keyReleased then
    focused.class.keyReleased(focused, key)
  end
end

function love.textinput(text)
  local focused = getFocusedElement()
  if focused and focused.class.textInput then
    focused.class.textInput(focused, text)
  end
end

function love.update(dt)
  updateCursor()
end

function love.draw()
  uiScene:begin()

  testSplitView:render(0, 0, lg.getDimensions())

  for _, w in ipairs(windows.list) do
    ---@cast w Window
    w:render(w.x, w.y, w.width, w.height)
  end

  for _, popup in ipairs(popups.list) do
    popup:render(unpack(popupViews[popup]))
  end

  uiScene:finish()
end

function love.quit()
  saveAllOpenResourceEditors()
  project.currentProject:saveToFile()
end

function love.resize()
  for _, w in ipairs(windows.list) do
    ---@cast w Window
    w:clampPosition()
  end
end
