local love = love
local lg = love.graphics

local hexToColor = require "util.hexToColor"
local zap = require "lib.zap.zap"
local tab = require "ui.tabView.tab"

---@class TabView: Zap.ElementClass
---@field private tabs Tab[]
---@field private activeTab Tab
---@field font love.Font
---@operator call:TabView
local tabView = zap.elementClass()

---Set the tabs shown by this TabContainer.
---@param tabs {text: string, content: Zap.Element}[]
function tabView:setTabs(tabs)
  self.tabs = {}
  for _, tabModel in ipairs(tabs) do
    local newTab = tab()
    newTab.text = tabModel.text
    newTab.content = tabModel.content
    newTab.font = self.font
    table.insert(self.tabs, newTab)
  end
  self:setActiveTab(self.tabs[1])
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

function tabView:render(x, y, w, h)
  local tabX = x
  for _, tab in ipairs(self.tabs) do
    local tabW = tab:preferredWidth()
    tab:render(tabX, y, tabW, self:tabBarHeight())
    tabX = tabX + tabW
    lg.setColor(hexToColor(0x2b2b2b))
    lg.setLineStyle("rough")
    lg.setLineWidth(1)
    lg.line(tabX, y, tabX, y + self:tabBarHeight())
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
