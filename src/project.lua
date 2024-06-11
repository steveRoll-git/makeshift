local uid = require "util.uid"
local uidToHex = require "util.uidToHex"
local binConvert = require "util.binConvert"
local parser = require "lang.parser"
local outputLua = require "lang.outputLua"
local numberToBytes = binConvert.numberToBytes
local bytesToNumber = binConvert.bytesToNumber

local untitledSceneName = "Untitled Scene"

local projectsDirectory = "projects/"
local projectFileExtension = ".makeshift"

local binaryTagTypes = {
  scene = 1,
  objectData = 2,
  script = 3,
}
---@type table<number, ResourceType>
local binaryTagLookup = {}
for k, v in pairs(binaryTagTypes) do
  binaryTagLookup[v] = k
end

local resourceBytes = {
  external = '\xfe',
  embedded = '\xfd'
}

local projectFileMagic = "makeshiftproject"

---@alias ResourceType "scene" | "objectData" | "script"

---@class Resource
---@field id string
---@field name string
---@field type ResourceType

---Creates a new resource of the specified type.
---@param type ResourceType
---@return Resource
function MakeResource(type)
  return {
    id = uid(),
    type = type
  }
end

---@class Project
---@field name string
---@field windowWidth number
---@field windowHeight number
---@field initialSceneId string
---@field resources table<string, Resource>
local project = {}
project.__index = project

function project.new(init)
  return setmetatable(init or {}, project)
end

---Adds a resource to the project.
---@param resource Resource
function project:addResource(resource)
  self.resources[resource.id] = resource
end

---Looks for an embedded resource with `id` inside the given `resource`.
---@param id string
---@param resource Resource
---@return Resource?
function project:searchForResource(id, resource)
  if id == resource.id then
    return resource
  end
  if resource.type == "scene" then
    ---@cast resource Scene
    for _, o in ipairs(resource.objects) do
      local found = self:searchForResource(id, o.data)
      if found then
        return found
      end
    end
  elseif resource.type == "objectData" then
    ---@cast resource ObjectData
    if resource.script.id == id then
      return resource.script
    end
  end
end

---Finds and returns the resource with this id.
---@param id string
---@return Resource?
function project:getResourceById(id)
  if self.resources[id] then
    return self.resources[id]
  end
  --TODO probably cache this process
  for _, resource in pairs(self.resources) do
    local found = self:searchForResource(id, resource)
    if found then
      return found
    end
  end
end

---Adds a new scene to the project and returns it.
function project:addScene()
  -- If there are already scenes named "Untitled Scene", append an incrementing number to the name.
  local lastUntitledNumber = 0
  for _, s in pairs(self.resources) do
    local number = s.name:match(untitledSceneName .. " ?(%d*)")
    if #number > 0 then
      lastUntitledNumber = math.max(lastUntitledNumber, tonumber(number) + 1)
    else
      lastUntitledNumber = math.max(lastUntitledNumber, 1)
    end
  end

  local newScene = MakeResource("scene") --[[@as Scene]]
  newScene.name = untitledSceneName .. (lastUntitledNumber > 0 and (" " .. lastUntitledNumber) or "")
  newScene.objects = {}
  self:addResource(newScene)

  if not self.initialSceneId or #self.initialSceneId == 0 then
    self.initialSceneId = newScene.id
  end

  return newScene
end

---For every object in all scenes, compile its script and store it.
---@return boolean success Whether compilation of all object scripts succeeded.
---@return SyntaxError[] errors A list of errors encountered during compilation.
function project:compileScripts()
  ---@type SyntaxError[]
  local errors = {}
  for _, r in pairs(self.resources) do
    if r.type == "scene" then
      ---@cast r Scene
      for _, obj in ipairs(r.objects) do
        local script = obj.data.script
        if #script.code > 0 then
          local p = parser.new(script.code, script)
          local ast = p:parseObjectCode()
          if #p.errorStack > 0 then
            table.insert(errors, p.errorStack[1])
            goto nextObject
          end
          local luaCode, sourceMap = outputLua(ast, script)
          local func, loadstringError = loadstring(luaCode, uidToHex(script.id))
          if not func then
            error(loadstringError)
          end
          script.compiledCode = {
            code = luaCode,
            func = func,
            sourceMap = sourceMap
          }
        end
      end
    end
    ::nextObject::
  end
  return #errors <= 0, errors
end

function project:saveToFile()
  love.filesystem.createDirectory(projectsDirectory)

  local f = love.filesystem.newFile(projectsDirectory .. self.name .. projectFileExtension)
  f:open("w")

  ---Writes the string's length, then the string itself.
  ---@param str string
  local function writeString(str)
    f:write(numberToBytes(#str))
    f:write(str)
  end

  ---@param number number
  local function writeNumber(number)
    f:write(numberToBytes(number))
  end

  local writeEmbeddedOrExternalResource

  ---@param r Resource
  local function writeResource(r)
    -- Write the resource's id, name and type.
    f:write(r.id)
    writeString(r.name or "")
    f:write(string.char(binaryTagTypes[r.type]))

    if r.type == "scene" then
      ---@cast r Scene
      writeNumber(#r.objects)
      for _, o in ipairs(r.objects) do
        writeNumber(o.x)
        writeNumber(o.y)
        writeEmbeddedOrExternalResource(o.data)
      end
    elseif r.type == "objectData" then
      ---@cast r ObjectData
      writeNumber(r.w)
      writeNumber(r.h)
      writeNumber(#r.frames)
      for _, frame in ipairs(r.frames) do
        local encodedData = frame.imageData:encode("png")
        writeNumber(encodedData:getSize())
        f:write(encodedData)
      end
      writeEmbeddedOrExternalResource(r.script)
    elseif r.type == "script" then
      ---@cast r Script
      writeString(r.code)
    else
      error(("can't write this resource type: %q"):format(r.type))
    end
  end

  ---@param resource Resource
  writeEmbeddedOrExternalResource = function(resource)
    if self.resources[resource.id] then
      f:write(resourceBytes.external)
      f:write(resource.id)
    else
      f:write(resourceBytes.embedded)
      writeResource(resource)
    end
  end

  f:write(projectFileMagic)
  --TODO write editor version info here

  writeString(self.name)
  writeNumber(self.windowWidth)
  writeNumber(self.windowHeight)
  writeString(self.initialSceneId)

  local totalResources = 0
  for _, _ in pairs(self.resources) do totalResources = totalResources + 1 end
  writeNumber(totalResources)

  for _, r in pairs(self.resources) do
    writeResource(r)
  end

  f:close()
end

function project:loadFromFile(projectName)
  local file = love.filesystem.newFile(projectsDirectory .. projectName .. projectFileExtension)
  file:open("r")

  local function readNumber()
    local contents = file:read(4)
    return bytesToNumber(contents)
  end

  local function readString()
    local size = readNumber()
    return file:read(size)
  end

  ---@param expectedType? ResourceType
  local function readResource(expectedType)
    local id = file:read(UIDLength)
    local name = readString()
    local type = binaryTagLookup[file:read(1):byte()]
    if expectedType and type ~= expectedType then
      error(("Expected a resource of type %q, but got %q"):format(expectedType, type))
    end

    ---@type Resource
    local resource = { id = id, name = name, type = type }

    if type == "scene" then
      ---@cast resource Scene

      resource.objects = {}
      local numObjects = readNumber()
      for i = 1, numObjects do
        local x = readNumber()
        local y = readNumber()
        local resourceOrValue = file:read(1)
        local objectData
        if resourceOrValue == resourceBytes.external then
          error("TODO")
        elseif resourceOrValue == resourceBytes.embedded then
          objectData = readResource("objectData") --[[@as ObjectData]]
        else
          error()
        end
        resource.objects[#resource.objects + 1] = {
          x = x,
          y = y,
          data = objectData
        }
      end
    elseif type == "objectData" then
      ---@cast resource ObjectData

      resource.w = readNumber()
      resource.h = readNumber()
      resource.frames = {}

      local numFrames = readNumber()
      for i = 1, numFrames do
        local size = readNumber()
        local data = love.image.newImageData(file:read("data", size))
        local frame = {
          imageData = data,
          image = love.graphics.newImage(data)
        }
        frame.image:setFilter("linear", "nearest")
        resource.frames[#resource.frames + 1] = frame
      end

      local scriptResourceOrValue = file:read(1)
      if scriptResourceOrValue == resourceBytes.external then
        error("TODO")
      elseif scriptResourceOrValue == resourceBytes.embedded then
        resource.script = readResource("script") --[[@as Script]]
      else
        error()
      end
    elseif type == "script" then
      ---@cast resource Script

      resource.code = readString()
    else
      error(("can't read this resource type: %q"):format(type))
    end

    return resource
  end

  local magic = file:read(#projectFileMagic)
  if magic ~= projectFileMagic then
    error()
  end

  self.name = readString()
  self.windowWidth = readNumber()
  self.windowHeight = readNumber()
  self.initialSceneId = readString()
  self.resources = {}

  local numResources = readNumber()
  for i = 1, numResources do
    local resource = readResource()
    self.resources[resource.id] = resource
  end

  return self
end

if love.filesystem.getInfo(projectsDirectory .. "Untitled Project" .. projectFileExtension) then
  project.currentProject = project.new():loadFromFile("Untitled Project")
else
  project.currentProject = project.new {
    name = "Untitled Project",
    resources = {},
    windowWidth = 800,
    windowHeight = 600,
    initialSceneId = "",
  }
  project.currentProject:addScene()
end

return project
