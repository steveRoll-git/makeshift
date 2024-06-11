---Given a list of values, returns a lookup table where each original value is a key to `true`.
---@param t table
---@return table<any, true>
return function(t)
  local new = {}
  for _, k in ipairs(t) do
    new[k] = true
  end
  return new
end
