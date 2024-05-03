local love = love
local lg = love.graphics

local hexToColor = require "util.hexToColor"
local zap = require "lib.zap.zap"
local tab = require "ui.tabView.tab"

---@alias TabModel {text: string, content: Zap.Element}

---@class TabView: Zap.ElementClass
---@field tabs Tab[]
---@field private activeTab Tab
---@field font love.Font
---@operator call:TabView
local tabView = zap.elementClass()

---Adds a new tab.
---@param tabModel TabModel
function tabView:addTab(tabModel)
  local newTab = tab()
  newTab.text = tabModel.text
  newTab.content = tabModel.content
  newTab.font = self.font
  newTab.draggable = true
  table.insert(self.tabs, newTab)
  self:layoutTabs()
  self:setActiveTab(newTab)
end

---Set the tabs shown by this TabContainer.
---@param tabs TabModel[]
function tabView:setTabs(tabs)
  self.tabs = {}
  for _, tabModel in ipairs(tabs) do
    self:addTab(tabModel)
  end
  self:layoutTabs()
  self:setActiveTab(self.tabs[1])
end

---Set a tab's index.
---@param tab Tab
---@param index number
function tabView:setTabIndex(tab, index)
  table.remove(self.tabs, tab.index)
  table.insert(self.tabs, index, tab)
  self:layoutTabs()
end

---Update all the tabs' `index` and `layoutX` according to their index.
function tabView:layoutTabs()
  local x = 0
  for i, tab in ipairs(self.tabs) do
    tab.layoutX = x
    tab.index = i
    x = x + tab:preferredWidth()
  end
end

---Sets the active tab.
---@param tab Tab
function tabView:setActiveTab(tab)
  if self.activeTab then
    self.activeTab.active = false
  end
  self.activeTab = tab
  self.activeTab.active = true
end

function tabView:tabBarHeight()
  return self.font:getHeight() + 16
end

---@param tab Tab
---@param x number
---@param y number
function tabView:renderTab(tab, x, y)
  local tabX = (tab.isDragging and tab.dragX or x + tab.layoutX)
  local tabW = tab:preferredWidth()
  tab:render(tabX, y, tabW, self:tabBarHeight())
end

function tabView:render(x, y, w, h)
  for _, tab in ipairs(self.tabs) do
    if tab ~= self.activeTab then
      self:renderTab(tab, x, y)
    end
  end
  if self.activeTab then
    self:renderTab(self.activeTab, x, y)
  end
  self.activeTab.content:render(x, y + self:tabBarHeight(), w, h - self:tabBarHeight())
  lg.setColor(hexToColor(0x2b2b2b))
  lg.setLineStyle("rough")
  lg.setLineWidth(1)
  local ax, _, aw, _ = self.activeTab:getView()
  lg.line(x, y + self:tabBarHeight(), ax, y + self:tabBarHeight())
  lg.line(ax + aw - 1, y + self:tabBarHeight(), x + w, y + self:tabBarHeight())
end

return tabView
