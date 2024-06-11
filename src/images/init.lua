local love = love
local lfs = love.filesystem

local imageDir = "images/"

local function shortPath(s)
  return s:sub(#imageDir + 1)
end

---@type table<string, love.Image>
local images = {}

setmetatable(images, {
  __index = function(t, k)
    local status, image = pcall(love.graphics.newImage, imageDir .. k)
    if not status then
      error(("image doesn't exist: %q"):format(k), 2)
    end
    images[k] = image
    return image
  end
})

return images
