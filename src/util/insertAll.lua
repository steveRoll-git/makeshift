---Inserts all elements in `elements` into `t`.
---@param t any[]
---@param elements any[]
return function(t, elements)
  for _, v in ipairs(elements) do
    table.insert(t, v)
  end
end
