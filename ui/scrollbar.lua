local love = love
local lg = love.graphics

local width = 16
local cornerRadius = width / 2

local scrollbar = {}
scrollbar.__index = scrollbar

function scrollbar.new()
  return setmetatable({}, scrollbar)
end

function scrollbar:draw()
  lg.setColor(1, 1, 1)
  lg.rectangle("fill",)
end

return scrollbar
