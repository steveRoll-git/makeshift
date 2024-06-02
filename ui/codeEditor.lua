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
local errorBubble = require "ui.errorBubble"

local font = fonts("SourceCodePro-Regular.ttf", 16)

local gradientTop = lg.newMesh({
  { 0, 0, 0, 0, 1, 1, 1, 1 },
  { 1, 0, 0, 0, 1, 1, 1, 1 },
  { 1, 1, 0, 0, 1, 1, 1, 0 },
  { 0, 1, 0, 0, 1, 1, 1, 0 },
})
local gradientBottom = lg.newMesh({
  { 0, 0, 0, 0, 1, 1, 1, 0 },
  { 1, 0, 0, 0, 1, 1, 1, 0 },
  { 1, 1, 0, 0, 1, 1, 1, 1 },
  { 0, 1, 0, 0, 1, 1, 1, 1 },
})

---@class CodeEditor: ResourceEditor
---@operator call:CodeEditor
local codeEditor = zap.elementClass()

---@param script Script
function codeEditor:init(script)
  self.script = script
  self.textEditor = textEditor()
  self.textEditor.font = font
  self.textEditor.multiline = true
  self.textEditor.preserveIndents = true
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

function codeEditor:showError()
  self.errorBubble = errorBubble(RunningPlaytest.engine.errorMessage)
  self.errorBubble.tailY = font:getHeight() / 2 + errorBubble.padding
  self.errorBubble:setContained(true)
  self.textEditor:jumpToLine(RunningPlaytest.engine.errorLine)
end

---Converts a line number to its pixel Y position.
---@param line number
---@return number
function codeEditor:lineToY(line)
  return (line - 1) * font:getHeight() + self.textEditor:actualOffsetY()
end

function codeEditor:playtestStarted()
  self.errorBubble = nil
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

  if RunningPlaytest and RunningPlaytest.engine.errorScript == self.script then
    lg.setColor(0.5, 0, 0, 0.5)
    lg.rectangle(
      "fill",
      x + self.leftColumnWidth,
      y + self:lineToY(RunningPlaytest.engine.errorLine),
      w - self.scrollbarY:desiredWidth() - self.leftColumnWidth,
      font:getHeight())
  end

  if RunningPlaytest and RunningPlaytest.engine.loopStuckScript == self.script then
    local startLine = RunningPlaytest.engine.loopStuckStartLine --[[@as number]]
    local endLine = RunningPlaytest.engine.loopStuckEndLine --[[@as number]]
    local startY = y + self:lineToY(startLine)
    local endY = y + self:lineToY(endLine + 1)
    lg.setColor(1, 1, 1, 0.25)
    lg.draw(
      gradientTop,
      x + self.leftColumnWidth,
      startY,
      0,
      w - self.leftColumnWidth,
      font:getHeight() / 2)
    lg.draw(
      gradientTop,
      x + self.leftColumnWidth,
      endY,
      0,
      w - self.leftColumnWidth,
      -font:getHeight() / 2)

    pushScissor(x + self.leftColumnWidth, startY, w - self.leftColumnWidth, endY - startY)
    local streakY =
        startY + ((love.timer.getTime() * 4) % (endLine - startLine + 3)) * font:getHeight()
    lg.setColor(1, 1, 1, 0.1)
    lg.draw(
      gradientTop,
      x + self.leftColumnWidth,
      streakY,
      0,
      w - self.leftColumnWidth,
      -font:getHeight())
    popScissor()
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

  if RunningPlaytest and self.errorBubble then
    self.errorBubble:render(
      x + self.leftColumnWidth + self.textEditor.lines[RunningPlaytest.engine.errorLine].width + font:getWidth("  "),
      y + self:lineToY(RunningPlaytest.engine.errorLine) - errorBubble.padding,
      self.errorBubble:desiredWidth(),
      self.errorBubble:desiredHeight()
    )
  end

  if self.scrollbarY.contentSize() > self.scrollbarY.viewSize() then
    self.scrollbarY:render(x + w - self.scrollbarY:desiredWidth(), y, self.scrollbarY:desiredWidth(), h)
  end

  popScissor()
end

return codeEditor
