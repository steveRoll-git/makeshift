local guid = require "util.guid"

local untitledSceneName = "Untitled Scene"

---@class Resource
---@field id string
---@field name string

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
    objects = {}
  }
  addResource(newScene)
  return newScene
end

local function getResources()
  return currentProject.resources
end

return {
  addScene = addScene,
  getResources = getResources,
}
