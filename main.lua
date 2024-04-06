local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"

local sceneEditor = require "ui.sceneEditor"

local hexToColor = require "util.hexToColor"

---@type Scene
local testScene = {
  name = "test",
  objects = {
    {
      image = lg.newImage("images/transparency.png"),
      x = 200,
      y = 100
    }
  }
}

local editor = sceneEditor(testScene)

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
  editor:render(0, 0, lg.getDimensions())
  uiScene:finish()
end
