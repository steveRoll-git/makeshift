local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local Tab = require "ui.components.tabView.tab"

---@alias TabModel {text: string, icon: love.Image?, content: Zap.Element, closable: boolean, dockable?: boolean}

---@class TabView: Zap.ElementClass
---@field tabs Tab[]
---@field activeTab Tab
---@field font love.Font
---@field focused boolean
---@operator call:TabView
local TabView = zap.elementClass()

function TabView:init()
  self.tabs = {}
end

---Adds a new tab.
---@param tabModel TabModel
---@return Tab
function TabView:addTab(tabModel)
  local newTab = Tab()
  newTab.text = tabModel.text
  newTab.icon = tabModel.icon
  newTab.content = tabModel.content
  newTab.font = self.font
  newTab.draggable = true
  newTab.closable = tabModel.closable
  newTab.dockable = tabModel.dockable
  table.insert(self.tabs, newTab)
  self:layoutTabs()
  self:setActiveTab(newTab)
  return newTab
end

---Set the tabs shown by this TabContainer.
---@param tabs TabModel[]
function TabView:setTabs(tabs)
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
function TabView:setTabIndex(tab, index)
  table.remove(self.tabs, tab.index)
  table.insert(self.tabs, index, tab)
  self:layoutTabs()
end

---Update all the tabs' `index` and `layoutX` according to their index.
function TabView:layoutTabs()
  local x = 0
  for i, tab in ipairs(self.tabs) do
    tab.layoutX = x
    tab.index = i
    x = x + tab:desiredWidth()
  end
end

---Sets the active tab.
---@param tab Tab
function TabView:setActiveTab(tab)
  if self.activeTab then
    self.activeTab.active = false
  end
  self.activeTab = tab
  self.activeTab.active = true
end

---Removes this tab without calling the `saveResource` callback.
---@param tab Tab
function TabView:removeTab(tab)
  table.remove(self.tabs, tab.index)
  self:layoutTabs()
  if self.activeTab == tab then
    if #self.tabs > 0 then
      self:setActiveTab(self.tabs[math.max(tab.index - 1, 1)])
    else
      self.activeTab = nil
    end
  end
end

---Closes this tab.
---@param tab Tab
function TabView:closeTab(tab)
  self:removeTab(tab)
  if tab.content.class.saveResource then
    tab.content.class.saveResource(tab.content)
  end
end

function TabView:tabBarHeight()
  return self.font:getHeight() + 16
end

---Returns whether the mouse is over the TabView's tab area.
---@return boolean
function TabView:isMouseOverTabBar()
  return self:isMouseOver() and select(2, self:getRelativeMouse()) < self:tabBarHeight()
end

---@param tab Tab
---@param x number
---@param y number
function TabView:renderTab(tab, x, y)
  local tabX = (tab.isDragging and tab.dragX or x + tab.layoutX)
  local tabW = tab:desiredWidth()
  tab:render(tabX, y, tabW, self:tabBarHeight())
end

function TabView:keyPressed(key)
  if self.activeTab and self.activeTab.content.class.keyPressed then
    self.activeTab.content.class.keyPressed(self.activeTab.content, key)
  end
end

function TabView:keyReleased(key)
  if self.activeTab and self.activeTab.content.class.keyReleased then
    self.activeTab.content.class.keyReleased(self.activeTab.content, key)
  end
end

function TabView:textInput(text)
  if self.activeTab and self.activeTab.content.class.textInput then
    self.activeTab.content.class.textInput(self.activeTab.content, text)
  end
end

function TabView:render(x, y, w, h)
  for _, tab in ipairs(self.tabs) do
    if tab ~= self.activeTab then
      self:renderTab(tab, x, y)
    end
  end
  if self.activeTab then
    self:renderTab(self.activeTab, x, y)
    self.activeTab.content:render(x, y + self:tabBarHeight(), w, h - self:tabBarHeight())
    lg.setColor(self.focused and CurrentTheme.outlineActive or CurrentTheme.outline)
    lg.setLineStyle("rough")
    lg.setLineWidth(1)
    local ax, _, aw, _ = self.activeTab:getView()
    lg.line(x, y + self:tabBarHeight(), ax, y + self:tabBarHeight())
    lg.line(ax + aw - 1, y + self:tabBarHeight(), x + w, y + self:tabBarHeight())
  end
end

return TabView
