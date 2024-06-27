local pushScissor = require "util.scissorStack".pushScissor
local popScissor = require "util.scissorStack".popScissor

---@alias SplitOrientation "horizontal" | "vertical"

return {
  ---Pads the view.
  ---@param x number
  ---@param y number
  ---@param w number
  ---@param h number
  ---@param padding number
  ---@return number x
  ---@return number y
  ---@return number w
  ---@return number h
  padding = function(x, y, w, h, padding)
    return
        x + padding,
        y + padding,
        w - padding * 2,
        h - padding * 2
  end,

  ---Renders two elements side by side, either horizontally or vertically.
  ---@param x number
  ---@param y number
  ---@param w number
  ---@param h number
  ---@param side1 Zap.Element
  ---@param side2 Zap.Element
  ---@param orientation SplitOrientation
  ---@param distance number
  ---@param scissor? boolean
  renderSplit = function(x, y, w, h, side1, side2, orientation, distance, scissor)
    local horizontal = orientation == "horizontal"
    local vertical = orientation == "vertical"

    local x2 = horizontal and x or x + distance
    local y2 = vertical and y or y + distance
    local w2 = horizontal and w or w - distance
    local h2 = vertical and h or h - distance
    if scissor then
      pushScissor(x2, y2, w2, h2)
    end
    side2:render(x2, y2, w2, h2)
    if scissor then
      popScissor()
    end

    local x1 = x
    local y1 = y
    local w1 = horizontal and w or distance
    local h1 = vertical and h or distance
    if scissor then
      pushScissor(x1, y1, w1, h1)
    end
    side1:render(x1, y1, w1, h1)
    if scissor then
      popScissor()
    end
  end
}
