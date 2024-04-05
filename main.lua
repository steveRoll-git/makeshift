local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"

local sceneEditor = require "ui.sceneEditor"

local editor = sceneEditor()

editor.engine:addObject({
  image = lg.newImage("images/transparency.png"),
  x = 200,
  y = 100
})

local scene = zap.createScene()

function love.mousemoved(x, y, dx, dy)
  scene:setMousePosition(x, y)
end

function love.mousepressed(x, y, btn)
  scene:mousePressed(btn)
end

function love.mousereleased(x, y, btn)
  scene:mouseReleased(btn)
end

function love.draw()
  scene:begin()
  editor:render(0, 0, lg.getDimensions())
  scene:finish()
end
