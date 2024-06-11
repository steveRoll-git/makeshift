---Linearly interpolate between two values.
---@param a number
---@param b number
---@param t number
---@return number
return function(a, b, t)
  return a + (b - a) * t
end
