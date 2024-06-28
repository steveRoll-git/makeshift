local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local Toolbar = require "ui.components.toolbar"
local images = require "images"
local TreeView = require "ui.components.treeView"
local Project = require "project"
local viewTools = require "util.viewTools"
local PopupMenu = require "ui.components.popupMenu"

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
  ---@type TreeView.ItemModel[]
  local items = {}
  for _, resource in pairs(Project.currentProject.resources) do
    items[#items + 1] = {
      text = resource.name,
      icon = resource.type == "scene" and images["icons/scene_24.png"] or nil,
      onClick = function()
        OpenResourceTab(resource)
      end,
      onRightClick = function(item)
        local menu = PopupMenu()
        menu:setItems {
          {
            text = "Rename",
            action = function()
              item:startRename()
            end
          }
        }
        menu:popupAtCursor()
      end,
      onRename = function(_, name)
        RenameResource(resource, name)
      end
    }
  end

  self.treeView:setItems(items)
end

function LibraryPanel:render(x, y, w, h)
  local toolbarH = 28

  viewTools.renderSplit(
    x, y, w, h,
    self.toolbar, self.treeView,
    "horizontal",
    toolbarH
  )
end

return LibraryPanel
