---@param str string
---@param pattern string
---@return fun(): string?
return function(str, pattern)
  local delimFrom = 1
  local stop = false
  return function()
    if stop then
      return nil
    end
    local delimStart, nextDelim = str:find(pattern, delimFrom)
    if not delimStart then
      stop = true
      return str:sub(delimFrom, #str)
    end
    ---@cast nextDelim number
    local substr = str:sub(delimFrom, delimStart - 1)
    delimFrom = nextDelim + 1
    return substr
  end
end
