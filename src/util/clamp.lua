---@param x number
---@param a number
---@param b number
---@return number
return function(x, a, b)
  return math.min(math.max(x, a), b)
end
