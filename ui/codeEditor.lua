local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local hexToColor = require "util.hexToColor"
local textEditor = require "ui.textEditor"
local fonts = require "fonts"

local font = fonts("SourceCodePro-Regular.ttf", 16)

---@class CodeEditor: Zap.ElementClass
---@operator call:CodeEditor
local codeEditor = zap.elementClass()

---@param script Script
function codeEditor:init(script)
  self.script = script
  self.textEditor = textEditor()
  self.textEditor.font = font
  self.textEditor.multiline = true
  self.textEditor:setText(script.code)

  self.lineNumberColumnWidth = font:getWidth("9999")
  self.leftColumnWidth = self.lineNumberColumnWidth + font:getWidth("  ")
end

function codeEditor:write()
  self.script.code = self.textEditor:getString()
end

function codeEditor:onClose()
  self:write()
end

function codeEditor:keyPressed(key)
  self.textEditor:keyPressed(key)
end

function codeEditor:textInput(text)
  self.textEditor:textInput(text)
end

function codeEditor:render(x, y, w, h)
  self.textEditor:render(x + self.leftColumnWidth, y, w - self.leftColumnWidth, h)
  for i = 1, #self.textEditor.lines do
    lg.setColor(hexToColor(0x6e6e6e))
    lg.setFont(font)
    lg.printf(
      tostring(i),
      x,
      y + (i - 1) * font:getHeight() + self.textEditor:actualOffsetY(),
      self.lineNumberColumnWidth,
      "right")
  end
end

return codeEditor
