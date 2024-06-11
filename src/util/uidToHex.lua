---Converts a single string byte to a string hex representation of it.
---@param byte string
local function byteToHex(byte)
  return ("%02X"):format(byte:byte())
end

---Converts a UID string to a readable hex string representation of it.
---@param uid string
---@return string
return function(uid)
  return (uid:gsub(".", byteToHex))
end
