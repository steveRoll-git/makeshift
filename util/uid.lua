local random = love.math.random

UIDLength = 16

local template = ('.'):rep(UIDLength)

local function randomChar()
  return string.char(random(0, 255))
end

return function()
  return string.gsub(template, '.', randomChar)
end
