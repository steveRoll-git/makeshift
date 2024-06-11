local bit = require "bit"

return function(color)
  return love.math.colorFromBytes(
    bit.band(bit.rshift(color, 16), 0xff),
    bit.band(bit.rshift(color, 8), 0xff),
    bit.band(color, 0xff))
end
