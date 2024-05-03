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
  end
}
