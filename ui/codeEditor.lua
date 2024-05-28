local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local hexToColor = require "util.hexToColor"
local textEditor = require "ui.textEditor"
local fonts = require "fonts"
local scrollbar = require "ui.scrollbar"
local clamp = require "util.clamp"
local pushScissor = require "util.scissorStack".pushScissor
local popScissor = require "util.scissorStack".popScissor

local font = fonts("SourceCodePro-Regular.ttf", 16)

---@class CodeEditor: ResourceEditor
---@operator call:CodeEditor
local codeEditor = zap.elementClass()

---@param script Script
function codeEditor:init(script)
  self.script = script
  self.textEditor = textEditor()
  self.textEditor.font = font
  self.textEditor.multiline = true
  self.textEditor:setText(script.code)

  self.scrollbarY = scrollbar()
  self.scrollbarY.direction = "y"
  self.scrollbarY.targetTable = self.textEditor
  self.scrollbarY.targetField = "offsetY"
  self.scrollbarY.viewSize = function()
    return select(4, self:getView())
  end
  self.scrollbarY.contentSize = function()
    return self.textEditor:contentHeight() + self.scrollbarY.viewSize() - font:getHeight()
  end

  self.lineNumberColumnWidth = font:getWidth("99999")
  self.leftColumnWidth = self.lineNumberColumnWidth + font:getWidth("  ")
end

function codeEditor:resourceId()
  return self.script.id
end

function codeEditor:write()
  self.script.code = self.textEditor:getString()
end

function codeEditor:saveResource()
  self:write()
end

function codeEditor:keyPressed(key)
  self.textEditor:keyPressed(key)
end

function codeEditor:textInput(text)
  self.textEditor:textInput(text)
end

function codeEditor:wheelMoved(x, y)
  self.textEditor.offsetY = clamp(self.textEditor.offsetY - y * font:getHeight() * 3, 0, self.scrollbarY:maximumScroll())
end

function codeEditor:render(x, y, w, h)
  pushScissor(x, y, w, h)

  if RunningPlaytest and RunningPlaytest.engine.errorSource == self.script.id then
    lg.setColor(0.6, 0, 0, 0.5)
    lg.rectangle(
      "fill",
      x,
      y + (RunningPlaytest.engine.errorLine - 1) * font:getHeight() + self.textEditor:actualOffsetY(),
      w - self.scrollbarY:desiredWidth(),
      font:getHeight())
  end

  self.textEditor:render(x + self.leftColumnWidth, y, w - self.leftColumnWidth - self.scrollbarY:desiredWidth(), h)

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

  if self.scrollbarY.contentSize() > self.scrollbarY.viewSize() then
    self.scrollbarY:render(x + w - self.scrollbarY:desiredWidth(), y, self.scrollbarY:desiredWidth(), h)
  end

  popScissor()
end

return codeEditor
