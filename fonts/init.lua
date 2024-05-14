local fontsDirectory = "fonts/"

---@type table<string, table<number, love.Font>>
local cache = {}

---@param font string
---@param size number
return function(font, size)
  if not cache[font] then
    cache[font] = {}
  end
  if not cache[font][size] then
    cache[font][size] = love.graphics.newFont(fontsDirectory .. font, size)
  end
  return cache[font][size]
end
