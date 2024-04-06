local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local treeView = require "ui.treeView"

local sceneEditor = require "ui.sceneEditor"

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
  local panelW = 200
  libraryPanel:render(0, 0, panelW, lg.getHeight())
  editor:render(panelW, 0, lg.getWidth() - panelW, lg.getHeight())
  uiScene:finish()
end
