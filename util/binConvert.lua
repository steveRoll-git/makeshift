local ffi = require "ffi"

local stringNumber = ffi.new("union { char string[4]; float number; }")

---Converts a lua number to a binary string containing its value.
---@param n number
---@return string
local function numberToBytes(n)
  stringNumber.number = n
  return ffi.string(stringNumber.string, 4)
end

---Converts a binary string to a lua number.
---@param str string
local function bytesToNumber(str)
  stringNumber.string = str
  return stringNumber.number
end

return {
  numberToBytes = numberToBytes,
  bytesToNumber = bytesToNumber,
}
