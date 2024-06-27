local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local Toolbar = require "ui.components.toolbar"
local images = require "images"
local TreeView = require "ui.components.treeView"
local Project = require "project"

---@class LibraryPanel: Zap.ElementClass
---@operator call:LibraryPanel
local LibraryPanel = zap.elementClass()

function LibraryPanel:init()
  self.toolbar = Toolbar()
  self.toolbar:setItems {
    {
      text = "Add Scene",
      image = images["icons/scene_add_18.png"],
      displayMode = "image",
      action = function()

      end
    }
  }

  self.treeView = TreeView()
  self:updateItems()
end

function LibraryPanel:updateItems()
  local items = {}
  for _, resource in pairs(Project.currentProject.resources) do
    table.insert(items, {
      text = resource.name,
      icon = resource.type == "scene" and images["icons/scene_24.png"],
      onClick = function()
        OpenResourceTab(resource)
      end
    })
  end

  self.treeView:setItems(items)
end

function LibraryPanel:render(x, y, w, h)
  local toolbarH = 28

  self.toolbar:render(x, y, w, toolbarH)

  self.treeView:render(x, y + toolbarH, w, h - toolbarH)
end

return LibraryPanel
