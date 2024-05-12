local love = love
local lg = love.graphics

local zap = require "lib.zap.zap"
local clamp = require "util.clamp"

---@alias TextPosition {line: number, col: number}

---The base for all text editing related elements.
---@class TextEditor: Zap.ElementClass
---@field font love.Font The font to use when displaying the text.
---@field lines {string: string, text: love.Text}[] A list of all the lines in the textEditor. Do not modify this externally.
---@field cursor TextPosition The current position of the cursor in the text.
---@field padding number The amount of padding to add in pixels.
---@field offsetX number Offset along the X axis, for both drawing and mouse handling.
---@field offsetY number Offset along the Y axis, for both drawing and mouse handling.
---@field cursorFlashSpeed number The frequency in flashes per second at which the cursor will flash.
---@field cursorFlashTime number The last time value at which the cursor started flashing.
---@field cursorWidth number The line width of the cursor.
---@field multiline boolean Whether this editor allows inserting newlines in text.
---@operator call:TextEditor
local textEditor = zap.elementClass()

function textEditor:init()
  self.lines = {}
  self.offsetX = 0
  self.offsetY = 0
  self.padding = 3
  self.cursor = {
    line = 1,
    col = 1,
    lastCol = 1
  }
  self.cursorFlashSpeed = 2
  self.cursorFlashTime = love.timer.getTime()
  self.cursorWidth = 1
end

function textEditor:actualOffsetX()
  return self.offsetX + self.padding
end

function textEditor:actualOffsetY()
  return self.offsetY + self.padding
end

---Sets the text currently being edited.
---@param text string
function textEditor:setText(text)
  self.lines = {}
  for str in text:gmatch("([^\n]+)") do
    table.insert(self.lines, { string = str, text = lg.newText(self.font, str) })
  end
end

---Inserts `text` into where the cursor is.
---@param text string
function textEditor:insertText(text)
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
      elseif c ~= "\r" then
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
  self:flashCursor()
end

---Inserts a newline into where the cursor is.
function textEditor:newLine()
  local newString = self:curString():sub(self.cursor.col)
  local line = {
    string = newString,
    text = lg.newText(self.font, newString)
  }
  table.insert(self.lines, self.cursor.line + 1, line)
  self.lines[self.cursor.line].string = self:curString():sub(1, self.cursor.col - 1)
  self.cursor.line = self.cursor.line + 1
  self:updateLine(self.cursor.line - 1)
  self:updateCurLine()
  self.cursor.col = 1
  self.cursor.lastCol = self.cursor.col
end

---Updates the text displayed on line `i`.
---@param i number
function textEditor:updateLine(i)
  local l = self.lines[i]
  l.text:set(l.string)
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

---Get the height of all the content in this textEditor, including all the lines and padding.
---@return number
function textEditor:contentHeight()
  return #self.lines * self.font:getHeight() + self.padding * 2
end

---Takes a text position (line and column) and returns a pixel position based on the current font.
---@param pos TextPosition
---@return number x, number y
function textEditor:textToScreenPos(pos)
  return
      self.font:getWidth(self.lines[pos.line].string:sub(1, pos.col - 1)) + 1,
      (pos.line - 1) * self.font:getHeight()
end

---Returns the screen position of the cursor.
---@return number x, number y
function textEditor:screenCursorPosition()
  return self:textToScreenPos(self.cursor)
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

function textEditor:keyPressed(key)
  local ctrlDown = love.keyboard.isDown("lctrl", "rctrl")
  local prevLine, prevCol = self.cursor.line, self.cursor.col

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
  elseif (key == "return" or key == "kpenter") and self.multiline then
    self:newLine()
  elseif key == "backspace" then
    if self.cursor.col > 1 then
      self.lines[self.cursor.line].string =
          self:curString():sub(1, self.cursor.col - 2) ..
          self:curString():sub(self.cursor.col)
      self:updateCurLine()
      self.cursor.col = self.cursor.col - 1
    elseif self.cursor.line > 1 then
      local deletedLine = table.remove(self.lines, self.cursor.line)
      deletedLine.text:release()
      self.cursor.line = self.cursor.line - 1
      self.cursor.col = #self:curString() + 1
      self.lines[self.cursor.line].string = self:curString() .. deletedLine.string
      self:updateCurLine()
    end
  elseif key == "delete" then
    if self.cursor.col < #self:curString() + 1 then
      self.lines[self.cursor.line].string =
          self:curString():sub(1, self.cursor.col - 1) ..
          self:curString():sub(self.cursor.col + 1)
      self:updateCurLine()
    elseif self.cursor.line < #self.lines then
      local deletedLine = table.remove(self.lines, self.cursor.line + 1)
      deletedLine.text:release()
      self.lines[self.cursor.line].string = self:curString() .. deletedLine.string
      self:updateCurLine()
    end
  end

  self:flashCursor()
end

function textEditor:textInput(text)
  self:insertText(text)
end

function textEditor:mousePressed(button)
  if button == 1 then
    self.cursor.line, self.cursor.col = self:screenToTextPos(self:getRelativeMouse())
    self:flashCursor()
  end
end

function textEditor:render(x, y, w, h)
  lg.push()
  lg.translate(x + self:actualOffsetX(), y + self:actualOffsetY())

  for i, line in ipairs(self.lines) do
    lg.setColor(1, 1, 1)
    lg.draw(line.text, 0, (i - 1) * self.font:getHeight())
  end

  if math.floor(love.timer.getTime() * self.cursorFlashSpeed - self.cursorFlashTime) % 2 == 0 then
    lg.setColor(1, 1, 1)
    lg.setLineStyle("rough")
    lg.setLineWidth(self.cursorWidth)
    local dx, dy = self:screenCursorPosition()
    lg.line(dx, dy, dx, dy + self.font:getHeight())
  end

  lg.pop()
end

return textEditor
