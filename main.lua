local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local treeView = require "ui.treeView"
local sceneEditor = require "ui.sceneEditor"
local tabView = require "ui.tabView"

local hexToColor = require "util.hexToColor"

local project = require "project"

local newScene = project.addScene()

table.insert(newScene.objects, {
  image = lg.newImage("images/transparency.png"),
  x = 200,
  y = 100
})

local editor = sceneEditor(newScene)

local libraryPanel = treeView()

local function sceneItemModels()
  ---@type TreeItemModel[]
  local items = {}
  for _, scene in pairs(project.getScenes()) do
    table.insert(items, { text = scene.name })
  end
  return items
end

libraryPanel:setItems(sceneItemModels())

local testTabView = tabView()
testTabView.font = lg.getFont()
testTabView:setTabs {
  {
    text = "Wow a Scene",
    content = editor
  },
  {
    text = "Scenes List",
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
end

function love.mousereleased(x, y, btn)
  uiScene:mouseReleased(btn)
end

function love.draw()
  uiScene:begin()
  testTabView:render(0, 0, lg.getDimensions())
  uiScene:finish()
end
