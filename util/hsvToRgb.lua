---@param h number
---@param s number
---@param v number
---@param a number
return function(h, s, v, a)
  h = h / 360
  s = s / 100
  v = v / 100

  local i = math.floor(h * 6)
  local f = h * 6 - i
  local p = v * (1 - s)
  local q = v * (1 - f * s)
  local t = v * (1 - (1 - f) * s)

  i = i % 6

  if i == 0 then
    return v, t, p, a
  elseif i == 1 then
    return q, v, p, a
  elseif i == 2 then
    return p, v, t, a
  elseif i == 3 then
    return p, q, v, a
  elseif i == 4 then
    return t, p, v, a
  elseif i == 5 then
    return v, p, q, a
  end
end
