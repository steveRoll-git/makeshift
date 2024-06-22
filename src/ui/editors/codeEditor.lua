local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local textEditor = require "ui.components.textEditor"
local fontCache = require "util.fontCache"
local scrollbar = require "ui.components.scrollbar"
local clamp = require "util.clamp"
local pushScissor = require "util.scissorStack".pushScissor
local popScissor = require "util.scissorStack".popScissor
local errorBubble = require "ui.components.errorBubble"
local parser = require "lang.parser"
local syntaxErrorBar = require "ui.components.syntaxErrorBar"
local images = require "images"

local font = fontCache.get("SourceCodePro-Regular.ttf", 16)

local gradientTop = lg.newMesh({
  { 0, 0, 0, 0, 1, 1, 1, 1 },
  { 1, 0, 0, 0, 1, 1, 1, 1 },
  { 1, 1, 0, 0, 1, 1, 1, 0 },
  { 0, 1, 0, 0, 1, 1, 1, 0 },
})

local squiggleImage = images["squiggleUnderline.png"]
squiggleImage:setWrap("repeat", "clamp")

-- How many seconds to wait after typing before checking syntax.
local syntaxCheckDelay = 0.5

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
  self.textEditor.indentSize = 2
  self.textEditor.syntaxHighlighting = {
    colors = CurrentTheme.codeEditor,
    styles = require "syntaxLanguages.makeshiftLang"
  }
  self.textEditor:setText(script.code)
  self.lastTypeTime = love.timer.getTime()
  self.textEditor.onTextChanged = function()
    self.checkedSyntax = false
    self.lastTypeTime = love.timer.getTime()
  end

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

function codeEditor:clearSyntaxError()
  self.syntaxError = nil
  self.syntaxErrorBar = nil
end

function codeEditor:checkSyntax()
  self:clearSyntaxError()

  self:saveResource()
  local p = parser.new(self.script.code, self.script)
  local ast = p:parseObjectCode()
  if #p.errorStack > 0 then
    self.syntaxError = p.errorStack[1]
    self.syntaxErrorBar = syntaxErrorBar()
    self.syntaxErrorBar.error = self.syntaxError
  end

  self.checkedSyntax = true
end

---Converts a line number to its pixel Y position.
---@param line number
---@return number
function codeEditor:lineToY(line)
  return (line - 1) * font:getHeight() + self.textEditor:actualOffsetY()
end

local squiggleQuad = lg.newQuad(0, 0, 0, 0, 0, 0)

---@param fromLine number
---@param fromCol number
---@param toLine number
---@param toCol number
function codeEditor:drawSquiggle(fromLine, fromCol, toLine, toCol)
  local x1, y1 = self.textEditor:textToScreenPos(fromLine, fromCol)
  local x2, y2 = self.textEditor:textToScreenPos(toLine, toCol)
  y1 = y1 + self.textEditor.font:getBaseline()
  y2 = y2 + self.textEditor.font:getBaseline()
  squiggleQuad:setViewport(
    0,
    0,
    math.max(x2 - x1, self.textEditor.font:getWidth(" ")),
    squiggleImage:getHeight(),
    squiggleImage:getDimensions()
  )
  lg.draw(squiggleImage, squiggleQuad, x1, y1)
end

function codeEditor:playtestStarted()
  self.errorBubble = nil
  self:checkSyntax()
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
  if not self.checkedSyntax and love.timer.getTime() >= self.lastTypeTime + syntaxCheckDelay then
    self:checkSyntax()
  end

  lg.setColor(CurrentTheme.backgroundActive)
  lg.rectangle("fill", x, y, w, h)

  pushScissor(x, y, w, h)

  if RunningPlaytest and RunningPlaytest.engine.errorScript == self.script then
    lg.setColor(CurrentTheme.codeEditor.lineBackgroundError)
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
    lg.setColor(1, 1, 1, 0.25) -- unstyled
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
    lg.setColor(1, 1, 1, 0.1) -- unstyled
    lg.draw(
      gradientTop,
      x + self.leftColumnWidth,
      streakY,
      0,
      w - self.leftColumnWidth,
      -font:getHeight())
    popScissor()
  end

  if self.syntaxError then
    h = h - self.syntaxErrorBar:desiredHeight()
  end

  self.textEditor:render(x + self.leftColumnWidth, y, w - self.leftColumnWidth - self.scrollbarY:desiredWidth(), h)

  for i = 1, #self.textEditor.lines do
    lg.setColor(CurrentTheme.codeEditor.lineNumber)
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

  if self.syntaxError then
    self.syntaxErrorBar:render(x, y + h, w, self.syntaxErrorBar:desiredHeight())

    lg.setColor(CurrentTheme.codeEditor.underlineError)
    lg.push()
    lg.translate(x + self.leftColumnWidth, y)
    self:drawSquiggle(
      self.syntaxError.fromLine,
      self.syntaxError.fromColumn,
      self.syntaxError.toLine,
      self.syntaxError.toColumn
    )
    lg.pop()
  end

  if self.scrollbarY.contentSize() > self.scrollbarY.viewSize() then
    self.scrollbarY:render(x + w - self.scrollbarY:desiredWidth(), y, self.scrollbarY:desiredWidth(), h)
  end

  popScissor()
end

return codeEditor
