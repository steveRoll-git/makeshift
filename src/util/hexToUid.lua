---Converts a two-character hex string to its corresponding byte string.
---@param str string
---@return string
local function hexToByte(str)
  return string.char(tonumber(str, 16))
end

---Converts a hex string to a UID string.
---@param str string
---@return string
return function(str)
  return (str:gsub("..", hexToByte))
end
