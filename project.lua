local guid = require "util.guid"
local binConvert = require "util.binConvert"
local numberToBytes = binConvert.numberToBytes
local bytesToNumber = binConvert.bytesToNumber

local untitledSceneName = "Untitled Scene"

local projectsDirectory = "projects/"
local projectFileExtension = ".makeshift"

local binaryTagTypes = {
  scene = 1,
  objectData = 2,
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

---@class Project
---@field name string
---@field resources table<string, Resource>

---@type Project
local currentProject = {
  name = "Untitled Project",
  resources = {}
}

---Adds a resource to the project.
---@param resource Resource
local function addResource(resource)
  currentProject.resources[resource.id] = resource
end

---Adds a new scene to the project.
local function addScene()
  -- If there are already scenes named "Untitled Scene", append an incrementing number to the name.
  local lastUntitledNumber = 0
  for _, s in pairs(currentProject.resources) do
    local number = s.name:match(untitledSceneName .. " ?(%d*)")
    if #number > 0 then
      lastUntitledNumber = math.max(lastUntitledNumber, tonumber(number) + 1)
    else
      lastUntitledNumber = math.max(lastUntitledNumber, 1)
    end
  end

  local id = guid()
  ---@type Scene
  local newScene = {
    id = id,
    name = untitledSceneName .. (lastUntitledNumber > 0 and (" " .. lastUntitledNumber) or ""),
    type = "scene",
    objects = {}
  }
  addResource(newScene)
  return newScene
end

local function getResources()
  return currentProject.resources
end

local function saveProject()
  love.filesystem.createDirectory(projectsDirectory)

  local f = love.filesystem.newFile(projectsDirectory .. currentProject.name .. projectFileExtension)
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
    if resource.id then
      f:write(resourceBytes.external)
      f:write(resource.id)
    else
      f:write(resourceBytes.embedded)
      writeResource(resource)
    end
  end

  f:write(projectFileMagic)
  --TODO write editor version info here

  writeString(currentProject.name)

  local totalResources = 0
  for _, _ in pairs(currentProject.resources) do totalResources = totalResources + 1 end
  writeNumber(totalResources)

  for _, r in pairs(currentProject.resources) do
    f:write(r.id)
    writeString(r.name)
    f:write(string.char(binaryTagTypes[r.type]))
    writeResource(r)
  end

  f:close()
end

local function loadProject(name)
  ---@type Project
  ---@diagnostic disable-next-line: missing-fields
  local project = {}

  local file = love.filesystem.newFile(projectsDirectory .. name .. projectFileExtension)
  file:open("r")

  local function readNumber()
    local contents = file:read(4) --[[@as string]]
    return bytesToNumber(contents)
  end

  local function readString()
    local size = readNumber()
    return (file:read(size) --[[@as string]])
  end

  ---@param type ResourceType
  local function readResource(type)
    if type == "scene" then
      ---@type Scene
      local scene = { type = "scene", objects = {} }
      local numObjects = readNumber()
      for i = 1, numObjects do
        local x = readNumber()
        local y = readNumber()
        local resourceOrValue = file:read(1) --[[@as string]]
        local objectData
        if resourceOrValue == resourceBytes.external then
          error("TODO")
        elseif resourceOrValue == resourceBytes.embedded then
          objectData = readResource("objectData") --[[@as ObjectData]]
        else
          error()
        end
        scene.objects[#scene.objects + 1] = {
          x = x,
          y = y,
          data = objectData
        }
      end
      return scene
    elseif type == "objectData" then
      local w = readNumber()
      local h = readNumber()
      ---@type ObjectData
      local objectData = {
        type = "objectData",
        w = w,
        h = h,
        frames = {},
        script = { type = "script", code = "" }
      }

      local numFrames = readNumber()
      for i = 1, numFrames do
        local size = readNumber()
        local data = love.image.newImageData(love.filesystem.newFileData(file:read(size)))
        local frame = {
          imageData = data,
          image = love.graphics.newImage(data)
        }
        frame.image:setFilter("linear", "nearest")
        objectData.frames[#objectData.frames + 1] = frame
      end

      local scriptResourceOrValue = file:read(1)
      if scriptResourceOrValue == resourceBytes.external then
        error("TODO")
      elseif scriptResourceOrValue == resourceBytes.embedded then
        objectData.script = readResource("script") --[[@as Script]]
      else
        error()
      end

      return objectData
    elseif type == "script" then
      ---@type Script
      local script = { type = "script", code = "" }
      script.code = readString()
      return script
    else
      error(("can't read this resource type: %q"):format(type))
    end
  end

  local magic = file:read(#projectFileMagic)
  if magic ~= projectFileMagic then
    error()
  end

  project.name = readString()
  project.resources = {}

  local numResources = readNumber()
  for i = 1, numResources do
    local id = file:read(36) --[[@as string]]
    local resourceName = readString()
    local resType = binaryTagLookup[file:read(1) --[[@as string]]:byte()]
    local resource = readResource(resType)
    resource.id = id
    resource.name = resourceName
    project.resources[id] = resource
  end

  return project
end

if love.filesystem.getInfo(projectsDirectory .. "Untitled Project" .. projectFileExtension) then
  currentProject = loadProject("Untitled Project")
else
  addScene()
end

return {
  addScene = addScene,
  getResources = getResources,
  saveProject = saveProject,
  loadProject = loadProject,
}
