local love = love
local lfs = love.filesystem

local imageDir = "images/"

local function shortPath(s)
  return s:sub(#imageDir+1)
end

---@type table<string, love.Image>
local images = {}

local function addDirectory(path)
  for _, f in ipairs(lfs.getDirectoryItems(path)) do
    local type = lfs.getInfo(path .. f).type
    if type == "file" and f:sub(-4) == ".png" then
      images[shortPath(path) .. f] = love.graphics.newImage(path .. f)
    elseif type == "directory" then
      addDirectory(path .. f .. "/")
    end
  end
end

addDirectory(imageDir)

setmetatable(images, {__index = function(t, k)
    error(("image doesn't exist: %q"):format(k), 2)
  end
})

return images
