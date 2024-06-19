local fontsDirectory = "fonts/"

---@class FontCache
---@field base FontCache?
---@field cache table<string, table<number, love.Font>>
local fontCache = {}
fontCache.__index = fontCache

---Creates a new FontCache.
---@param base? FontCache
---@return FontCache
local function newFontCache(base)
  local self = setmetatable({}, fontCache)
  self.base = base
  self.cache = {}
  return self
end

---Returns the font only if it's cached, otherwise returns nil.
---@param font string
---@param size number
---@return love.Font?
function fontCache:tryGet(font, size)
  return (self.cache[font] and self.cache[font][size]) or (self.base and self.base:tryGet(font, size))
end

---Returns the cached font if it exists, otherwise creates it and returns it.
---@param font string
---@param size number
---@return love.Font
function fontCache:get(font, size)
  if self.base then
    local baseFont = self.base:tryGet(font, size)
    if baseFont then
      return baseFont
    end
  end

  if not self.cache[font] then
    self.cache[font] = {}
  end
  if not self.cache[font][size] then
    self.cache[font][size] = love.graphics.newFont(fontsDirectory .. font, size)
  end
  return self.cache[font][size]
end

local defaultCache = newFontCache()

return {
  defaultCache = defaultCache,

  ---@param font string
  ---@param size number
  ---@return love.Font?
  tryGet = function(font, size)
    return defaultCache:tryGet(font, size)
  end,

  ---@param font string
  ---@param size number
  ---@return love.Font
  get = function(font, size)
    return defaultCache:get(font, size)
  end,

  new = newFontCache,
}
