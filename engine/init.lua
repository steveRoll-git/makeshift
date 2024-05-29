local love = love
local lg = love.graphics

local orderedSet = require "util.orderedSet"
local deepCopy = require "util.deepCopy"
local strongType = require "lang.strongType"
local hexToUID = require "util.hexToUid"
local project = require "project"

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

-- How many seconds to wait while `stuckInLoop` before showing it to the user.
local loopStuckWaitDuration = 3

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
  if active then
    self.running = true

    --Stores events that were emitted while the game stalled, to be executed once the game gets running again.
    self.pendingEvents = {}

    self.scriptEnvironment = self:createEnvironment()

    --Counts the number of times a specific loop iterated in a single update.
    ---@type table<string, number>
    self.loopCounts = {}

    -- This coroutine is responsible for running user code, which yields in loops.
    -- This is needed in order to give back control to makeshift in case user code
    -- runs in a loop and doesn't exit from it.
    self.codeRunner = coroutine.create(function(...)
      while true do
        ---@type RuntimeObject, string, any, any, any, any
        local object, event, p1, p2, p3, p4 = coroutine.yield("eventEnd")
        local f = object.events[event]
        if f then
          f(object, p1, p2, p3, p4)
        end
      end
    end)
    coroutine.resume(self.codeRunner)
  end

  self.objects = orderedSet.new()
  if scene then
    for _, obj in ipairs(scene.objects) do
      local newObj = deepCopy(obj)
      if active and obj.data.script.compiledCode then
        ---@cast newObj RuntimeObject
        setfenv(obj.data.script.compiledCode.func, self.scriptEnvironment)
        newObj.events = obj.data.script.compiledCode.func()
        newObj.scriptInstance = objectType:instance(newObj)
      end
      self:addObject(newObj)
    end
  end
end

---Decodes the error message string to figure out which script and on which line the error occured,
---and opens the code editor for that script.
---@param fullMessage string
function engine:handleError(fullMessage)
  local source, line, message = fullMessage:match('%[string "(.*)"%]:(%d*): (.*)')
  self.errorSource = hexToUID(source)
  local script = project.currentProject:getResourceById(self.errorSource)
  if not script then
    return
  end
  ---@cast script Script
  self.errorScript = script
  local actualLine
  local sourceMap = script.compiledCode.sourceMap
  for i = tonumber(line), 1, -1 do
    if sourceMap[i] then
      actualLine = sourceMap[i]
      break
    end
  end
  self.errorMessage = message
  self.errorLine = actualLine
  self:openErroredCodeEditor()
end

---Opens the resource editor for the script where the current error happened.
function engine:openErroredCodeEditor()
  local editor = OpenResourceTab(self.errorScript) --[[@as CodeEditor]]
  editor:showError()
end

---Figures out the Script and line which the code is currently suck on.
function engine:parseLoopStuckCode()
  local maxStuckLoop
  local maxStuckLoopCount
  for k, v in pairs(self.loopCounts) do
    if not maxStuckLoopCount or v > maxStuckLoopCount then
      maxStuckLoop = k
      maxStuckLoopCount = v
    end
  end
  local id, startLine, endLine = maxStuckLoop:match("loop (%w+) (%d+) (%d+)")
  self.loopStuckScript = project.currentProject:getResourceById(hexToUID(id)) --[[@as Script]]
  self.loopStuckStartLine = tonumber(startLine)
  self.loopStuckEndLine = tonumber(endLine)
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
  local stillInLoop = true

  -- whether the initial call to `resume` was already done for this event
  local ranInitial = not object

  for _ = 1, maxLoopYields do
    local success, result
    if not ranInitial then
      ranInitial = true
      success, result = coroutine.resume(self.codeRunner, object, event, p1, p2, p3, p4)
    else
      success, result = coroutine.resume(self.codeRunner)
    end
    if success then
      if result:find("loop") then
        self.loopCounts[result] = (self.loopCounts[result] or 0) + 1
      elseif result == "eventEnd" then
        stillInLoop = false
        break
      else
        error("unknown coroutine result? " .. result)
      end
    else
      self.running = false
      self:handleError(result)
      break
    end
  end

  if stillInLoop then
    self.loopStuckTime = self.loopStuckTime or love.timer.getTime()
    self.stuckInLoop = true
  else
    self.loopStuckTime = nil
    self.stuckInLoop = false
    while next(self.loopCounts) do
      self.loopCounts[next(self.loopCounts)] = nil
    end
    self.loopStuckScript = nil
    self.loopStuckStartLine = nil
  end
end

-- starts executing an object's method. it may finish running in the same call,
-- but it may also enter a stuck loop from here.
---@param object RuntimeObject
---@param event string
---@param p1 any
---@param p2 any
---@param p3 any
---@param p4 any
function engine:callObjectEvent(object, event, p1, p2, p3, p4)
  if not self.running then
    return
  end

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

  if self.stuckInLoop and not self.loopStuckScript and love.timer.getTime() > self.loopStuckTime + loopStuckWaitDuration then
    self:parseLoopStuckCode()
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
