local orderedSet = require "util.orderedSet"
local love = love
local lg = love.graphics

---@class Object
---@field x number
---@field y number
---@field image love.Image

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
    lg.setColor(1, 1, 1)
    lg.draw(o.image, o.x, o.y)
  end
end

local function createEngine()
  local self = setmetatable({}, engine)
  self.objects = orderedSet.new()
  return self
end

return {
  createEngine = createEngine
}
