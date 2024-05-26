local lookupify = require "util.lookupify"

local vowels = lookupify { "a", "e", "i", "o", "u" }

---@param noun string
return function(noun)
  return (vowels[noun:sub(1, 1):lower()] and "an %s" or "a %s"):format(noun)
end
