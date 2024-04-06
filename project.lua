local guid = require "util.guid"

local untitledSceneName = "Untitled Scene"

---@class Project
---@field name string
---@field scenes table<string, Scene>

---@type Project
local currentProject = {
  name = "Untitled Project",
  scenes = {}
}

---Adds a new scene to the project.
local function addScene()
  -- If there are already scenes named "Untitled Scene", append an incrementing number to the name.
  local lastUntitledNumber = 0
  for _, s in pairs(currentProject.scenes) do
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
    name = untitledSceneName .. (lastUntitledNumber > 0 and (" " .. lastUntitledNumber) or ""),
    objects = {}
  }
  currentProject.scenes[id] = newScene
  return newScene
end

return {
  addScene = addScene
}
