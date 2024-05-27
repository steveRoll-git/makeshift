local love = love
local lg = love.graphics

local orderedSet = require "util.orderedSet"
local deepCopy = require "util.deepCopy"
local strongType = require "lang.strongType"

---@class Script: Resource
---@field code string
---@field compiledCode {code: string, func: function, sourceMap: table<number, number>}?

---@class ObjectData: Resource
---@field w number
---@field h number
---@field frames SpriteFrame[] A list of all the frames in this object. They are all assumed to be the same size.
---@field script Script

---@class Object
---@field x number
---@field y number
---@field data ObjectData

---@class RuntimeObject: Object
---@field events table<string, function>
---@field scriptInstance table

---@class SpriteFrame
---@field imageData love.ImageData
---@field image love.Image

---@class Scene: Resource
---@field objects Object[]

local objectType = strongType.new("object", {
  x = { type = "number" },
  y = { type = "number" },
})

-- the maximum amount of times to `yield` inside a loop before moving on.
local maxLoopYields = 1000

-- An instance of a running Makeshift engine.<br>
-- Used in the editor and the runtime.
---@class Engine
---@field objects OrderedSet
---@field runningObject RuntimeObject
local engine = {}
engine.__index = engine

---@param scene Scene?
---@param active boolean?
function engine:init(scene, active)
  self.objects = orderedSet.new()
  if scene then
    for _, obj in ipairs(scene.objects) do
      local newObj = deepCopy(obj)
      if active and obj.data.script.compiledCode then
        ---@cast newObj RuntimeObject
        newObj.events = obj.data.script.compiledCode.func()
        newObj.scriptInstance = objectType:instance(newObj)
      end
      self:addObject(newObj)
    end
  end

  if active then
    self.running = true

    self.pendingEvents = {}

    -- This coroutine is responsible for running user code, which yields in loops.
    -- This is needed in order to give back control to makeshift in case user code
    -- runs in a loop and doesn't exit from it.
    self.codeRunner = coroutine.create(function(...)
      while true do
        local object, event, p1, p2, p3, p4 = coroutine.yield("eventEnd")
        local f = object.events[event]
        if f then
          self:objectPcall(f, object, p1, p2, p3, p4)
        end
      end
    end)
    coroutine.resume(self.codeRunner)
  end
end

function engine:createEnvironment()
  return {
    _yield = coroutine.yield,
    keyDown = function(key)
      local success, result = pcall(love.keyboard.isDown, key)
      if not success then
        error(("%q is not a valid key"):format(key), 2)
      end
      return result
    end
  }
end

---Calls a function on an object, and goes into an error state if it errored.
---@param func function
---@param obj RuntimeObject
---@param ... any
function engine:objectPcall(func, obj, ...)
  local success, result = pcall(func, obj.scriptInstance, ...)
  if not success then
    self.running = false
    local source, line, message = result:match('%[string "(.*)"%]:(%d*): (.*)')
    local actualLine
    local sourceMap = obj.data.script.compiledCode.sourceMap
    for i = tonumber(line), 1, -1 do
      if sourceMap[i] then
        actualLine = sourceMap[i]
        break
      end
    end
    -- TODO show object name here
    self.error = ([[
[unnamed object]
Line %d:
%s
]]):format(actualLine, message)
    self.errorSource = source
    self.errorLine = actualLine
  end
end

-- Runs the event runner either until it finishes the current event, or
-- it runs a loop for more than a specified amount.
--
-- If parameters are given, it starts the runner with those parameters.
---@param object RuntimeObject
---@param event string
---@param p1 any
---@param p2 any
---@param p3 any
---@param p4 any
---@overload fun()
function engine:tryContinueRunner(object, event, p1, p2, p3, p4)
  self.runningObject = object or self.runningObject

  local stillInLoop = true

  -- whether the initial call to `resume` was already done for this event
  local ranInitial = not object

  -- TODO make this code differentiate nested loops
  for i = 1, maxLoopYields do
    local success, result
    if not ranInitial then
      ranInitial = true
      success, result = coroutine.resume(self.codeRunner, object, event, p1, p2, p3, p4)
    else
      success, result = coroutine.resume(self.codeRunner)
    end
    if success then
      local loopLine = result:match("loop (%d+)")
      if loopLine then
        self.loopStuckLine = tonumber(loopLine)
      elseif result == "eventEnd" then
        stillInLoop = false
        self.runningObject = nil
        break
      else
        error("unknown coroutine result? " .. result)
      end
    else
      error(result)
    end
  end

  if stillInLoop then
    self.loopStuckTime = self.loopStuckTime or love.timer.getTime()
    self.stuckInLoop = true
  else
    self.loopStuckTime = nil
    self.stuckInLoop = false
  end
end

-- starts executing an object's method. it may finish running in the same call,
-- but it may also enter a stuck loop from here.
function engine:callObjectEvent(object, event, p1, p2, p3, p4)
  if not object.events or not object.events[event] then
    return
  end

  if self.stuckInLoop then
    -- insert this event to be executed later, after the code exits the stuck loop
    table.insert(self.pendingEvents, { object, event, p1, p2, p3, p4 })
    return
  end

  self:tryContinueRunner(object, event, p1, p2, p3, p4)
end

---Add an object into the scene.
---@param obj Object
function engine:addObject(obj)
  self.objects:add(obj)
end

function engine:update(dt)
  if not self.running then return end

  -- if the code is currently stuck in a loop, we only focus on trying to
  -- complete it (one batch of tries every frame), and only run updates after it's finished
  if self.stuckInLoop then
    self:tryContinueRunner()
  end
  while not self.stuckInLoop and #self.pendingEvents > 0 do
    self:callObjectEvent(unpack(table.remove(self.pendingEvents, 1)))
  end
  if not self.stuckInLoop then
    -- finally, if we're not stuck in a loop anymore, run the update event for all objects.
    for _, object in ipairs(self.objects.list) do
      -- TODO decide whether to include deltatime or not
      self:callObjectEvent(object, "update")
    end
  end
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
---@param active boolean?
---@return Engine
local function createEngine(scene, active)
  local self = setmetatable({}, engine)
  self:init(scene, active)
  return self
end

return {
  createEngine = createEngine
}
