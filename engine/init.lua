local orderedSet = require "util.orderedSet"
local deepCopy = require "util.deepCopy"
local love = love
local lg = love.graphics

---@class Script: Resource
---@field code string

---@class ObjectData: Resource
---@field w number
---@field h number
---@field frames SpriteFrame[] A list of all the frames in this object. They are all assumed to be the same size.
---@field script Script

---@class Object
---@field x number
---@field y number
---@field data ObjectData

---@class SpriteFrame
---@field imageData love.ImageData
---@field image love.Image

---@class Scene: Resource
---@field objects Object[]

-- An instance of a running Makeshift engine.<br>
-- Used in the editor and the runtime.
---@class Engine
---@field objects OrderedSet
local engine = {}
engine.__index = engine

---Add an object into the scene.
---@param obj Object
function engine:addObject(obj)
  self.objects:add(obj)
end

function engine:draw()
  for _, o in ipairs(self.objects.list) do
    ---@cast o Object
    lg.setColor(1, 1, 1)
    lg.draw(o.data.frames[1].image, o.x, o.y)
  end
end

---Creates a new Engine.
---@param scene Scene?
---@return Engine
local function createEngine(scene)
  local self = setmetatable({}, engine)
  self.objects = orderedSet.new()
  if scene then
    for _, obj in ipairs(scene.objects) do
      self:addObject(deepCopy(obj))
    end
  end
  return self
end

return {
  createEngine = createEngine
}
