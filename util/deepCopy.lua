---@generic T
---@param value T
---@return T
local function deepCopy(value)
  local t = type(value)
  if t == "table" then
    local new = {}
    for k, v in pairs(value) do
      new[k] = deepCopy(v)
    end
    return new
  end
  return value
end

return deepCopy
