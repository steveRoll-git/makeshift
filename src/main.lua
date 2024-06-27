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

CurrentTheme = require "themes.defaultDark"

local zap = require "lib.zap.zap"
local TreeView = require "ui.components.treeView"
local SceneEditor = require "ui.editors.sceneEditor"
local TabView = require "ui.components.tabView"
local SpriteEditor = require "ui.editors.spriteEditor"
local fontCache = require "util.fontCache"
local hexToColor = require "util.hexToColor"
local Project = require "project"
local images = require "images"
local OrderedSet = require "util.orderedSet"
local Window = require "ui.components.window"
local SplitView = require "ui.components.splitView"
local Playtest = require "ui.components.playtest"
local CodeEditor = require "ui.editors.codeEditor"
local LibraryPanel = require "ui.editors.libraryPanel"

require "util.scissorStack"

---@type Playtest?
RunningPlaytest = nil

local uiScene = zap.createScene()

---@class Zap.ElementClass
---@field mouseDoubleClicked fun(self: Zap.Element, button: any)
---@field keyPressed fun(self: Zap.Element, key: string)
---@field keyReleased fun(self: Zap.Element, key: string)
---@field popupClosed fun(self: Zap.Element)
---@field textInput fun(self: Zap.Element, text: string)
---@field playtestStarted fun(self: Zap.Element)
---@field getCursor fun(self: Zap.Element): love.Cursor
---@field saveResource fun(self: Zap.Element)

---An Element that edits a certain resource.
---@class ResourceEditor: Zap.ElementClass
---@field resourceId fun(self: Zap.Element): string

local popups = OrderedSet.new()
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

local mainTabView = TabView()
mainTabView.font = fontCache.get("Inter-Regular.ttf", 14)
mainTabView.focused = true

local windows = OrderedSet.new()

---@type Window?
local focusedWindow

---@param w Window?
function SetFocusedWindow(w)
  if focusedWindow then
    focusedWindow.focused = false
  else
    mainTabView.focused = false
  end
  focusedWindow = w
  if w then
    w.focused = true
    if windows:getIndex(w) ~= windows:getCount() then
      windows:remove(w)
      windows:add(w)
    end
  else
    mainTabView.focused = true
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
  if focusedWindow == w then
    SetFocusedWindow(windows:last())
  end
end

---@param w Window
function CloseWindow(w)
  if w.content.class.saveResource then
    w.content.class.saveResource(w.content)
  end
  RemoveWindow(w)
  if w.content == RunningPlaytest then
    RunningPlaytest = nil
  end
end

local explorerTabView = TabView()
explorerTabView.font = fontCache.get("Inter-Regular.ttf", 14)
explorerTabView:setTabs {
  {
    text = "Library",
    icon = images["icons/library_24.png"],
    content = LibraryPanel(),
  },
}

local testSplitView = SplitView()
testSplitView.orientation = "vertical"
testSplitView.side1 = explorerTabView
testSplitView.side2 = mainTabView
testSplitView.splitDistance = 200

---Adds a new tab to the main tabView.
---@param tab TabModel
function AddNewTab(tab)
  mainTabView:addTab(tab)
end

---Opens a new tab to edit this resource, and returns the editor element.
---@param r Resource
---@return Zap.Element
function OpenResourceTab(r)
  local focused = FocusResourceEditor(r.id)
  if focused then
    return focused
  end
  local text
  local icon
  local content
  if r.type == "scene" then
    text = r.name
    icon = images["icons/scene_24.png"]
    content = SceneEditor(r)
  elseif r.type == "spriteData" then
    text = r.name
    icon = images["icons/brush_24.png"]
    content = SpriteEditor()
    content.editingSprite = r --[[@as SpriteData]]
  elseif r.type == "script" then
    text = "Code Editor"
    icon = images["icons/code_24.png"]
    content = CodeEditor(r)
  end
  AddNewTab {
    text = text,
    icon = icon,
    content = content,
    closable = true,
    dockable = true,
  }
  SetFocusedWindow(nil)
  return content
end

---Returns whether `element` is an editor of the resource with this ID.
---@param element Zap.Element
---@param id string
---@return boolean
local function isResourceEditor(element, id)
  local class = element.class --[[@as ResourceEditor]]
  return class.resourceId and class.resourceId(element) == id
end

---Searches for a tab or window that is editing the resource with this ID, focuses it if it's found and returns it.
---@param id string
---@return Zap.Element? found The element that is editing this resource.
function FocusResourceEditor(id)
  for _, tView in ipairs(GetAllDockableTabViews()) do
    for _, tab in ipairs(tView.tabs) do
      if isResourceEditor(tab.content, id) then
        SetFocusedWindow(nil)
        tView:setActiveTab(tab)
        return tab.content
      end
    end
  end
  for _, w in ipairs(windows.list) do
    ---@cast w Window
    if isResourceEditor(w.content, id) then
      SetFocusedWindow(w)
      return w.content
    end
  end
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
  else
    return mainTabView
  end
end

---Emits an event for all currently open editors.
---@param event string
---@param ... any
local function emitEventForAllEditors(event, ...)
  for _, t in ipairs(mainTabView.tabs) do
    if t.content.class[event] then
      t.content.class[event](t.content)
    end
  end
  for _, w in ipairs(windows.list) do
    ---@cast w Window
    if w.content.class[event] then
      w.content.class[event](w.content)
    end
  end
end

---Calls the `saveResource` method for all currently open editors.
local function saveAllOpenResourceEditors()
  emitEventForAllEditors("saveResource")
end

local function runPlaytest()
  saveAllOpenResourceEditors()

  if RunningPlaytest then
    return
  end

  local success, errors = Project.currentProject:compileScripts()
  if not success then
    local editor = OpenResourceTab(errors[1].source) --[[@as CodeEditor]]
    editor:checkSyntax()
    return
  end

  local playtestWindow = Window()
  playtestWindow.titleFont = fontCache.get("Inter-Regular.ttf", 14)
  playtestWindow.title = "Playtest"
  playtestWindow.icon = images["icons/game_24.png"]
  playtestWindow:setContentSize(
    Project.currentProject.windowWidth,
    Project.currentProject.windowHeight
  )
  playtestWindow.x = math.floor(lg.getWidth() / 2 - playtestWindow.width / 2)
  playtestWindow.y = math.floor(lg.getHeight() / 2 - playtestWindow.height / 2)
  playtestWindow.closable = true
  RunningPlaytest = Playtest(Project.currentProject.resources[Project.currentProject.initialSceneId])
  playtestWindow.content = RunningPlaytest

  AddWindow(playtestWindow)
  emitEventForAllEditors("playtestStarted")
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
        break
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
  uiScene:pressMouse(btn, beforeMousePress)
  local pressedElement = uiScene:getPressedElement()

  if btn == lastPressButton and
      love.timer.getTime() - lastPressTime <= doubleClickTime and
      pressedElement == lastPressedElement and
      pressedElement.class.mouseDoubleClicked then
    pressedElement.class.mouseDoubleClicked(pressedElement, btn)
  end

  if pressedElement:getRoot().class == Window then
    SetFocusedWindow(pressedElement:getRoot() --[[@as Window]])
  else
    SetFocusedWindow(nil)
  end

  lastPressTime = love.timer.getTime()
  lastPressButton = btn
  lastPressedElement = pressedElement
end

function love.mousereleased(x, y, btn)
  uiScene:releaseMouse(btn)
end

function love.wheelmoved(x, y)
  uiScene:raiseMouseEvent("wheelMoved", x, y)
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

  if RunningPlaytest then
    RunningPlaytest:update(dt)
  end
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
  Project.currentProject:saveToFile()
end

function love.resize()
  for _, w in ipairs(windows.list) do
    ---@cast w Window
    w:clampPosition()
  end
end
