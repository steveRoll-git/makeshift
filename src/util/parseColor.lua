---Parses a color string into a color.
---@param str string
---@return number, number, number, number?
return function(str)
  local r, g, b, a = str:match("#(%x%x)(%x%x)(%x%x)(%x?%x?)")
  if r then
    return
        tonumber(r, 16) / 255,
        tonumber(g, 16) / 255,
        tonumber(b, 16) / 255,
        #a > 0 and tonumber(a, 16) / 255 or 1
  end
  error(("Unsupported color format: %q"):format(str))
end
