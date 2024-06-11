---@param a number
---@param b number
---@return boolean
local function componentEqual(a, b)
  return math.abs(a - b) < 1 / 255 - 0.0000001
end

---@param r1 number
---@param g1 number
---@param b1 number
---@param a1 number
---@param r2 number
---@param g2 number
---@param b2 number
---@param a2 number
---@overload fun(color1: number[], r2: number, g2: number, b2: number, a2: number)
---@overload fun(color1: number[], color2: number[])
return function(r1, g1, b1, a1, r2, g2, b2, a2)
  if type(r1) == "table" then
    if type(g1) == "table" then
      r2, g2, b2, a2 = unpack(g1)
    else
      r2, g2, b2, a2 = g1, b1, a1, r2
    end
    r1, g1, b1, a1 = unpack(r1)
  end
  a1 = a1 or 1
  a2 = a2 or 1
  return
      componentEqual(r1, r2) and
      componentEqual(g1, g2) and
      componentEqual(b1, b2) and
      componentEqual(a1, a2)
end
