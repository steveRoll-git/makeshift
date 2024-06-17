---Returns a reverse lookup of `t`.<br>
---For example, the reverse lookup of `{a = 1, b = 2}` is `{"a", "b"}`.
---@param t table
---@return table
return function(t)
  local new = {}
  for k, v in pairs(t) do
    new[v] = k
  end
  return new
end
