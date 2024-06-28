local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local TextEditor = require "ui.components.textEditor"

---@class TempEditor: Zap.ElementClass
---@field writeValue fun(value: string)
---@operator call:TempEditor
local TempEditor = zap.elementClass()

---@param value string
function TempEditor:init(value)
  self.textEditor = TextEditor()
  self.textEditor.centerVertically = true
  self.textEditor:setText(value)
  self.textEditor:selectAll()
end

---@param font love.Font
function TempEditor:setFont(font)
  self.textEditor:setFont(font)
end

function TempEditor:keyPressed(key)
  self.textEditor:keyPressed(key)
  if key == "escape" then
    self.cancel = true
    ClosePopup(self)
  elseif key == "return" or key == "kpenter" then
    ClosePopup(self)
  end
end

function TempEditor:textInput(text)
  self.textEditor:textInput(text)
end

function TempEditor:popupClosed()
  if not self.cancel then
    self.writeValue(self.textEditor:getString())
  end
end

function TempEditor:render(x, y, w, h)
  lg.setColor(CurrentTheme.backgroundInactive)
  lg.rectangle("fill", x, y, w, h, 3)
  self.textEditor:render(x, y, w, h)
end

return TempEditor
