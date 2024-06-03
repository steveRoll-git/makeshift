local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local clamp = require "util.clamp"
local splitString = require "util.splitString"
local popupMenu = require "ui.popupMenu"

---Returns `true` if `a` is positioned before `b`.
---@param a TextPosition
---@param b TextPosition
---@return boolean
local function comparePositions(a, b)
  if a.line == b.line then
    return a.col < b.col
  else
    return a.line < b.line
  end
end

---@alias TextPosition {line: number, col: number}

---@class SyntaxStylesTable
---@field patternStyles {[1]: string, [2]: string, word: boolean?}[] A list of {pattern, style} tuples.
---@field multilineStyles [string, string, string][] A list of {startString, endString, style} tuples, for styles that can start and end on different lines.

---The base for all text editing related elements.
---@class TextEditor: Zap.ElementClass
---@field font love.Font The font to use when displaying the text.
---@field lines {string: string, text: love.Text, width: number}[] A list of all the lines in the textEditor. Do not modify this externally.
---@field cursor TextPosition The current position of the cursor in the text.
---@field padding number The amount of padding to add in pixels.
---@field offsetX number Offset along the X axis, for both drawing and mouse handling.
---@field offsetY number Offset along the Y axis, for both drawing and mouse handling.
---@field cursorFlashSpeed number The frequency in flashes per second at which the cursor will flash.
---@field cursorFlashTime number The last time value at which the cursor started flashing.
---@field cursorWidth number The line width of the cursor.
---@field multiline boolean Whether this editor allows inserting newlines in text.
---@field preserveIndents boolean Whether to preserve indents when pressing enter.
---@field indentSize number? The number of spaces to insert when indenting.
---@field syntaxHighlighting {colors: table<string, number[]>, styles: SyntaxStylesTable}? Syntax highlighting to color text with.
---@field onTextChanged function?
---@field selecting boolean Whether a selection is currently active.
---@field selectionStart TextPosition The position where the selection starts.
---@field centerHorizontally boolean Whether to center the text horizontally inside the view. Currently works only on one line.
---@field centerVertically boolean Whether to center the text vertically inside the view.
---@operator call:TextEditor
local textEditor = zap.elementClass()

function textEditor:init()
  self.lines = {}
  self.offsetX = 0
  self.offsetY = 0
  self.padding = 0
  self.cursor = {
    line = 1,
    col = 1,
    lastCol = 1
  }
  self.selectionStart = { line = 1, col = 1 }
  self.cursorFlashSpeed = 2
  self.cursorFlashTime = love.timer.getTime()
  self.cursorWidth = 1
  self.selectionColor = { 1, 1, 1, 0.2 }
end

function textEditor:actualOffsetX()
  if self.centerHorizontally then
    local _, _, w, _ = self:getView()
    return math.floor(w / 2 - self.lines[1].width / 2)
  end
  return -self.offsetX + self.padding
end

function textEditor:actualOffsetY()
  if self.centerVertically then
    local _, _, _, h = self:getView()
    return math.floor(h / 2 - self:contentHeight() / 2)
  end
  return -self.offsetY + self.padding
end

---Sets the text currently being edited.
---@param text string
function textEditor:setText(text)
  self.lines = {}
  if #text == 0 then
    table.insert(self.lines, { string = "", text = lg.newText(self.font) })
    return
  end
  local current = 1
  for str in splitString(text, "\n") do
    table.insert(self.lines, { string = str, text = lg.newText(self.font) })
    self:updateLine(current)
    current = current + 1
  end
  self._textChanged = true
end

---Inserts `text` into where the cursor is.
---@param text string
function textEditor:insertText(text)
  if self.selecting then
    self:deleteSelection()
  end

  if text:find("\n") then
    local lastLine = ""
    for i = 1, #text do
      local c = text:sub(i, i)
      if self.multiline and c == "\n" or i == #text then
        if i == #text then lastLine = lastLine .. c end
        self.lines[self.cursor.line].string =
            self:curString():sub(1, self.cursor.col - 1) ..
            lastLine ..
            self:curString():sub(self.cursor.col)
        self.cursor.col = self.cursor.col + #lastLine
        if c == "\n" then self:newLine() end
        self:updateCurLine()
        lastLine = ""
      elseif c ~= "\r" and c ~= "\n" then
        lastLine = lastLine .. c
      end
    end
  else
    self.lines[self.cursor.line].string =
        self:curString():sub(1, self.cursor.col - 1) ..
        text ..
        self:curString():sub(self.cursor.col)
    self:updateCurLine()
    self.cursor.col = self.cursor.col + #text
    self.cursor.lastCol = self.cursor.col
  end

  self._textChanged = true
end

---Inserts a newline into where the cursor is.
function textEditor:newLine()
  if self.selecting then
    self:deleteSelection()
  end

  local orig = self:curString()
  local newString = orig:sub(self.cursor.col)
  local newCursorColumn = 1
  local line = {
    string = newString,
    text = lg.newText(self.font)
  }
  if self.preserveIndents then
    local indent = orig:match("^(%s*)")
    line.string = indent .. line.string
    newCursorColumn = #indent + 1
  end
  table.insert(self.lines, self.cursor.line + 1, line)
  self.lines[self.cursor.line].string = self:curString():sub(1, self.cursor.col - 1)
  self.cursor.line = self.cursor.line + 1
  self:updateLine(self.cursor.line - 1)
  self:updateCurLine()
  self.cursor.col = newCursorColumn
  self.cursor.lastCol = self.cursor.col

  self._textChanged = true
end

---Delete the currently selected text.
function textEditor:deleteSelection()
  local firstEdge = self:selectionFirstEdge()
  local lastEdge = self:selectionLastEdge()
  if firstEdge.line == lastEdge.line then
    self.lines[self.cursor.line].string =
        self:curString():sub(1, firstEdge.col - 1) ..
        self:curString():sub(lastEdge.col)
    self:updateCurLine()
  else
    self.lines[firstEdge.line].string =
        self.lines[firstEdge.line].string:sub(1, firstEdge.col - 1) ..
        self.lines[lastEdge.line].string:sub(lastEdge.col)
    self:updateLine(firstEdge.line)
    self.lines[lastEdge.line].string =
        self.lines[lastEdge.line].string:sub(lastEdge.col)
    table.remove(self.lines, lastEdge.line)
  end
  for _ = firstEdge.line + 1, lastEdge.line - 1 do
    table.remove(self.lines, firstEdge.line + 1)
  end
  if self.cursor ~= firstEdge then
    self.cursor.col, self.cursor.line = firstEdge.col, firstEdge.line
  end
  self.selecting = false
  self._textChanged = true
end

---Changes the indentation on line `i` - add indentation if `direction` is 1, or unindent if it's -1.
---@param i number
---@param direction 1 | -1
function textEditor:changeLineIndent(i, direction)
  local line = self.lines[i]
  local indent, rest = line.string:match("^(%s*)(.*)")
  local newIndent = (" "):rep((math.floor(#indent / self.indentSize) + direction) * self.indentSize)
  line.string = newIndent .. rest
  self:updateLine(i)
  if self.cursor.line == i then
    self.cursor.col = self.cursor.col - (#indent - #newIndent)
  end
  if self.selectionStart.line == i then
    self.selectionStart.col = self.selectionStart.col - (#indent - #newIndent)
  end
  self._textChanged = true
end

---Cuts the selected text into the system clipboard.
function textEditor:cut()
  self:copy()
  self:deleteSelection()
end

---Copies the selected text into the system clipboard.
function textEditor:copy()
  love.system.setClipboardText(self:getSelectionString())
end

---Inserts text from the system clipboard.
function textEditor:paste()
  self:insertText(love.system.getClipboardText())
end

function textEditor:selectAll()
  self.selecting = true
  self.cursor.line, self.cursor.col = 1, 1
  self.selectionStart.line, self.selectionStart.col = #self.lines, #self.lines[#self.lines].string + 1
end

---Returns a string with the lines in the given range joined together
---@param from number
---@param to number
---@return string
function textEditor:concatLines(from, to)
  local str = ""
  for i = from, to do
    str = str .. self.lines[i].string .. (i < to and "\n" or "")
  end
  return str
end

---Returns a string of the entire editor's contents.
---@return string
function textEditor:getString()
  return self:concatLines(1, #self.lines)
end

function textEditor:getSelectionString()
  if not self.selecting then
    return self:curString()
  elseif self:selectionFirstEdge().line == self:selectionLastEdge().line then
    return self.lines[self:selectionFirstEdge().line].string
        :sub(self:selectionFirstEdge().col, self:selectionLastEdge().col - 1)
  else
    local conc = self:concatLines(self:selectionFirstEdge().line + 1, self:selectionLastEdge().line - 1)
    return
        self.lines[self:selectionFirstEdge().line].string:sub(self:selectionFirstEdge().col) ..
        "\n" ..
        conc ..
        (self:selectionLastEdge().line > self:selectionFirstEdge().line + 1 and "\n" or "") ..
        self.lines[self:selectionLastEdge().line].string:sub(1, self:selectionLastEdge().col - 1)
  end
end

---Updates the text displayed on line `i`.
---@param i number
function textEditor:updateLine(i)
  local l = self.lines[i]
  if self.syntaxHighlighting then
    l.text:clear()
    local coloredText = {}
    local addedIndex = 0
    while addedIndex < #l.string + 1 do
      local matchIndex
      local matchString
      local matchStyle
      -- for every pattern style, we find the one closest to `addedIndex`.
      for _, pair in ipairs(self.syntaxHighlighting.styles.patternStyles) do
        local startIndex, endIndex = l.string:find(pair[1], addedIndex)
        if startIndex and
            (not matchIndex or startIndex < matchIndex) and
            (not pair.word or -- if the `word` flag is true, we check that the capture isn't sorrounded by alphanumeric characters.
              not l.string:sub(startIndex - 1, startIndex - 1):match("%w") and
              not l.string:sub(endIndex + 1, endIndex + 1):match("%w")) then
          matchIndex = startIndex
          matchString = l.string:sub(startIndex, endIndex)
          matchStyle = pair[2]
        end
      end
      if not matchIndex then
        table.insert(coloredText, self.syntaxHighlighting.colors.default)
        table.insert(coloredText, l.string:sub(addedIndex))
        break
      end
      if matchIndex > addedIndex then
        table.insert(coloredText, self.syntaxHighlighting.colors.default)
        table.insert(coloredText, l.string:sub(addedIndex, matchIndex - 1))
        addedIndex = matchIndex
      end
      if matchIndex == addedIndex then
        table.insert(coloredText, self.syntaxHighlighting.colors[matchStyle])
        table.insert(coloredText, matchString)
        addedIndex = addedIndex + #matchString
      end
    end
    l.text:add(coloredText)
  else
    l.text:set(l.string)
  end
  l.width = self.font:getWidth(l.string)
end

---Updates the line the cursor is currently on.
function textEditor:updateCurLine()
  self:updateLine(self.cursor.line)
end

---Returns the string of the line the cursor is currently on.
---@return string
function textEditor:curString()
  return self.lines[self.cursor.line].string
end

---Returns the position at which the selection begins.
---@return TextPosition
function textEditor:selectionFirstEdge()
  return comparePositions(self.cursor, self.selectionStart) and self.cursor or self.selectionStart
end

---Returns the position at which the selection ends.
---@return TextPosition
function textEditor:selectionLastEdge()
  return comparePositions(self.cursor, self.selectionStart) and self.selectionStart or self.cursor
end

---Get the height of all the content in this textEditor, including all the lines and padding.
---@return number
function textEditor:contentHeight()
  return #self.lines * self.font:getHeight() + self.padding * 2
end

---Takes a text position (line and column) and returns a pixel position based on the current font.
---@param line number
---@param column number
---@return number x, number y
function textEditor:textToScreenPos(line, column)
  return
      self.font:getWidth(self.lines[line].string:sub(1, column - 1)) + 1 + self:actualOffsetX(),
      (line - 1) * self.font:getHeight() + self:actualOffsetY()
end

---Returns the screen position of the cursor.
---@return number x, number y
function textEditor:screenCursorPosition()
  return self:textToScreenPos(self.cursor.line, self.cursor.col)
end

---Takes a screen position and returns the closest text position to it.
---@param x number
---@param y number
---@return number line
---@return number column
function textEditor:screenToTextPos(x, y)
  x = x - self:actualOffsetX()
  y = y - self:actualOffsetY()
  local line = clamp(math.ceil(y / self.font:getHeight()), 1, #self.lines)
  local lineUnderCursor = self.lines[line].string
  local col = #lineUnderCursor + 1
  for i = 1, #lineUnderCursor do
    local rightX = self.font:getWidth(lineUnderCursor:sub(1, i))
    if x <= rightX then
      if x > (self.font:getWidth(lineUnderCursor:sub(1, i - 1)) + rightX) / 2 then
        col = i + 1
      else
        col = i
      end
      break
    end
  end
  return line, col
end

---Resets `cursorFlashTime` to make the cursor flash now.
function textEditor:flashCursor()
  self.cursorFlashTime = love.timer.getTime() * self.cursorFlashSpeed
end

---Moves the cursor to the specified line.
---@param line number
function textEditor:jumpToLine(line)
  self.selecting = false
  self.cursor.line = line
end

---Calls the `onTextChanged` function if it exists.
function textEditor:callTextChanged()
  if self.onTextChanged then
    self.onTextChanged()
  end
end

function textEditor:keyPressed(key)
  self._textChanged = false

  local ctrlDown = love.keyboard.isDown("lctrl", "rctrl")
  local shiftDown = love.keyboard.isDown("lshift", "rshift")
  local prevLine, prevCol = self.cursor.line, self.cursor.col
  local cursorMoved = false

  if key == "left" then
    self.cursor.col = self.cursor.col - 1
    if self.cursor.col < 1 then
      if self.cursor.line > 1 then
        self.cursor.line = self.cursor.line - 1
        self.cursor.col = #self:curString() + 1
      else
        self.cursor.col = 1
      end
    end
    self.cursor.lastCol = self.cursor.col
    cursorMoved = true
  elseif key == "right" then
    self.cursor.col = self.cursor.col + 1
    if self.cursor.col > #self:curString() + 1 then
      if self.cursor.line < #self.lines then
        self.cursor.line = self.cursor.line + 1
        self.cursor.col = 1
      else
        self.cursor.col = #self:curString() + 1
      end
    end
    self.cursor.lastCol = self.cursor.col
    cursorMoved = true
  elseif key == "up" then
    if self.cursor.line == 1 then
      if self.cursor.col ~= 1 then
        self.cursor.col = 1
        self.cursor.lastCol = self.cursor.col
      end
    else
      self.cursor.line = self.cursor.line - 1
      self.cursor.col = self.cursor.lastCol
      if self.cursor.col > #self:curString() + 1 then
        self.cursor.col = #self:curString() + 1
      end
    end
    cursorMoved = true
  elseif key == "down" then
    if self.cursor.line == #self.lines then
      self.cursor.col = #self:curString() + 1
      self.cursor.lastCol = self.cursor.col
    else
      self.cursor.line = self.cursor.line + 1
      self.cursor.col = self.cursor.lastCol
      if self.cursor.col > #self:curString() + 1 then
        self.cursor.col = #self:curString() + 1
      end
    end
    cursorMoved = true
  elseif key == "home" then
    if ctrlDown then
      self.cursor.line = 1
    end
    self.cursor.col = 1
    self.cursor.lastCol = self.cursor.col
  elseif key == "end" then
    if ctrlDown then
      self.cursor.line = #self.lines
    end
    self.cursor.col = #self:curString() + 1
    self.cursor.lastCol = self.cursor.col
    cursorMoved = true
  elseif (key == "return" or key == "kpenter") and self.multiline then
    self:newLine()
  elseif key == "backspace" then
    if self.selecting then
      self:deleteSelection()
    elseif self.cursor.col > 1 then
      self.lines[self.cursor.line].string =
          self:curString():sub(1, self.cursor.col - 2) ..
          self:curString():sub(self.cursor.col)
      self:updateCurLine()
      self.cursor.col = self.cursor.col - 1
      self._textChanged = true
    elseif self.cursor.line > 1 then
      local deletedLine = table.remove(self.lines, self.cursor.line)
      deletedLine.text:release()
      self.cursor.line = self.cursor.line - 1
      self.cursor.col = #self:curString() + 1
      self.lines[self.cursor.line].string = self:curString() .. deletedLine.string
      self:updateCurLine()
      self._textChanged = true
    end
  elseif key == "delete" then
    if self.selecting then
      self:deleteSelection()
    elseif self.cursor.col < #self:curString() + 1 then
      self.lines[self.cursor.line].string =
          self:curString():sub(1, self.cursor.col - 1) ..
          self:curString():sub(self.cursor.col + 1)
      self:updateCurLine()
      self._textChanged = true
    elseif self.cursor.line < #self.lines then
      local deletedLine = table.remove(self.lines, self.cursor.line + 1)
      deletedLine.text:release()
      self.lines[self.cursor.line].string = self:curString() .. deletedLine.string
      self:updateCurLine()
      self._textChanged = true
    end
  elseif key == "tab" and self.indentSize then
    local fromLine = self.selecting and self:selectionFirstEdge().line or self.cursor.line
    local toLine = self.selecting and self:selectionLastEdge().line or self.cursor.line
    if shiftDown then
      for i = fromLine, toLine do
        self:changeLineIndent(i, -1)
      end
    elseif self.selecting then
      for i = fromLine, toLine do
        self:changeLineIndent(i, 1)
      end
    else
      self:insertText((" "):rep(self.indentSize - (self.cursor.col - 1) % self.indentSize))
    end
  elseif ctrlDown then
    if key == "x" then
      self:cut()
    elseif key == "c" then
      self:copy()
    elseif key == "v" then
      self:paste()
    elseif key == "a" then
      self:selectAll()
    end
  end

  if cursorMoved then
    if shiftDown then
      if not self.selecting then
        self.selecting = true
        self.selectionStart.line = prevLine
        self.selectionStart.col = prevCol
      end
    else
      self.selecting = false
    end
  end

  self:flashCursor()
  if self._textChanged then
    self:callTextChanged()
  end
end

function textEditor:textInput(text)
  self:insertText(text)
  self:callTextChanged()
end

function textEditor:mousePressed(button)
  if button == 1 then
    self.cursor.line, self.cursor.col = self:screenToTextPos(self:getRelativeMouse())
    if love.keyboard.isDown("lshift", "rshift") then
      self.selecting = true
    else
      self.selectionStart.line, self.selectionStart.col = self.cursor.line, self.cursor.col
      self.selecting = false
    end
    self:flashCursor()
  end
  if button == 2 then
    local menu = popupMenu()
    menu:setItems {
      {
        text = "Cut",
        action = function()
          self:cut()
          self:callTextChanged()
        end
      },
      {
        text = "Copy",
        action = function()
          self:copy()
        end
      },
      {
        text = "Paste",
        action = function()
          self:paste()
          self:callTextChanged()
        end
      },
      "separator",
      {
        text = "Select All",
        action = function()
          self:selectAll()
        end
      }
    }
    menu:popupAtCursor()
  end
end

function textEditor:mouseMoved()
  if self:isPressed(1) then
    self.cursor.line, self.cursor.col = self:screenToTextPos(self:getRelativeMouse())
    self.selecting = self.cursor.line ~= self.selectionStart.line or self.cursor.col ~= self.selectionStart.col
    self:flashCursor()
  end
end

function textEditor:getCursor()
  return love.mouse.getSystemCursor("ibeam")
end

function textEditor:render(x, y, w, h)
  if #self.lines == 0 then
    self:setText("")
  end

  lg.push()
  lg.translate(x + self:actualOffsetX(), y + self:actualOffsetY())

  for i, line in ipairs(self.lines) do
    local lineY = (i - 1) * self.font:getHeight()
    if self.selecting then
      if i >= self:selectionFirstEdge().line and i <= self:selectionLastEdge().line then
        lg.setColor(self.selectionColor)
        local startX, endX = 0, line.width
        if i == self:selectionFirstEdge().line then
          startX = self.font:getWidth(self.lines[i].string:sub(1, self:selectionFirstEdge().col - 1))
        end
        if i == self:selectionLastEdge().line then
          endX = self.font:getWidth(self.lines[i].string:sub(1, self:selectionLastEdge().col - 1))
        end
        if i < self:selectionLastEdge().line and self:selectionFirstEdge().line ~= self:selectionLastEdge().line then
          endX = endX + self.font:getWidth(" ")
        end
        lg.rectangle("fill", startX, lineY, endX - startX, self.font:getHeight())
      end
    end
    lg.setColor(1, 1, 1)
    lg.draw(line.text, 0, lineY)
  end

  lg.pop()

  if math.floor(love.timer.getTime() * self.cursorFlashSpeed - self.cursorFlashTime) % 2 == 0 then
    lg.setColor(1, 1, 1)
    lg.setLineStyle("rough")
    lg.setLineWidth(self.cursorWidth)
    local dx, dy = self:screenCursorPosition()
    dx = dx + x
    dy = dy + y
    lg.line(dx, dy, dx, dy + self.font:getHeight())
  end
end

return textEditor
