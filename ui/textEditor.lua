local love = love
local lg = love.graphics

local table = table

local math = math

local baseButton   = require "ui.baseButton"
local clamp        = require "util.clamp"
local split        = require "util.split"
local unorderedSet = require "util.unorderedSet"

local cursor_mt = {
  __lt = function(a, b)
    if a.line == b.line then
      return a.col < b.col
    else
      return a.line < b.line
    end
  end
}

local defaultTextPadding = 3

local cursorWidth = 2

local macros = {
  {
    triggerKey = "return",
    condition = function(self)
      return self.lastText:match(".*%{$")
    end,
    action = function(self)
      local indent = self.lines[self.cursor.line - 1].string:match("^(%s*)")
      self:newLine()
      self:inputText(indent .. "}")
      self:keypressed("up")
      self:keypressed("end")
    end
  }
}

local autoIndentPatterns = {
  ".*%{$"
}

local underlineImage = lg.newImage("images/squiggleUnderline.png")
underlineImage:setWrap("repeat")

local white = { 1, 1, 1 }

local editor = setmetatable({}, baseButton)
editor.__index = editor

editor.textPadding = defaultTextPadding
editor.doubleClickTime = 0.5

function editor.new(x, y, w, h, font, multiline, text, syntaxColors)
  font = font or lg.getFont()
  local obj = setmetatable(baseButton.new(x, y, w, h), editor)
  obj.font = font
  obj.syntaxColors = syntaxColors
  if text then
    obj.lines = {}
    for l in split(text, "\n") do
      table.insert(obj.lines, { string = l, text = lg.newText(font) })
      obj:updateLine(#obj.lines)
    end
  else
    obj.lines = { { string = "", text = lg.newText(font), totalWidth = 0 } }
  end
  obj.cursor = setmetatable({ line = 1, col = 1, lastCol = 1 }, cursor_mt)
  obj.selectStart = setmetatable({ line = 1, col = 1 }, cursor_mt)
  obj.selecting = false
  obj.flickTime = love.timer.getTime()
  obj.flickSpeed = 2
  obj.tabSize = 2
  obj.lastClick = { line = 1, col = 1 }
  obj.lastClickTime = 0
  obj.lastText = ""
  obj.multiline = multiline
  obj.selectionColor = { 0.678, 0.839, 1.000, 0.4 }
  obj.textX, obj.textY = defaultTextPadding, defaultTextPadding
  obj.underlines = unorderedSet.new()
  obj.stencilFunc = function()
    lg.rectangle("fill", 0, 0, obj.w, obj.h)
  end
  obj.keyboardFocus = true
  return obj
end

function editor:flick()
  self.flickTime = love.timer.getTime() * self.flickSpeed
end

function editor:curLine()
  return self.lines[self.cursor.line].string
end

local multilineEnd = "]]"

function editor:updateLine(i)
  i = i or self.cursor.line
  local line = self.lines[i]
  line.text:clear()

  if self.syntaxColors then
    line.multilineEnd = false

    local lastX = 0
    local j = 1

    if i > 1 then
      if self.lines[i - 1].multilineAffected then
        line.multilineAffected = self.lines[i - 1].multilineAffected

        while j <= #line.string do

          local char = line.string:sub(j, j)
          line.text:add({ line.multilineAffected, char }, lastX)
          lastX = lastX + self.font:getWidth(char)
          j = j + 1

          if line.string:sub(j - #multilineEnd, j - 1) == multilineEnd then
            line.multilineAffected = nil
            line.multilineEnd = true
            break
          end
        end
      else
        line.multilineAffected = nil
      end
    end

    local foundMultilineStart = false

    while j <= #line.string do

      local char = line.string:sub(j, j)

      if char == '"' or char == "'" then

        local stringStart = char
        local stringContent = ""
        repeat
          stringContent = stringContent .. line.string:sub(j, j)
          j = j + 1
        until (line.string:sub(j, j) == stringStart and line.string:sub(j - 1, j - 1) ~= "\\") or j >= #line.string

        stringContent = stringContent .. line.string:sub(j, j)
        j = j + 1

        line.text:add({ self.syntaxColors.string, stringContent }, lastX)
        lastX = lastX + self.font:getWidth(stringContent)
        goto foundword

      elseif char:find("%d") and not line.string:sub(j - 1, j - 1):find("[%w]") then

        local numberContent = ""
        repeat
          numberContent = numberContent .. line.string:sub(j, j)
          j = j + 1
        until (line.string:sub(j, j):find("[^%w%+%.]")) or j > #line.string

        line.text:add({ self.syntaxColors.number, numberContent }, lastX)
        lastX = lastX + self.font:getWidth(numberContent)
        goto foundword

      elseif line.string:sub(j, j + 1) == "[[" or line.string:sub(j, j + 3) == "--[[" then

        foundMultilineStart = true
        line.hasMultilineStart = true

        local isComment = line.string:sub(j, j + 1) == "--"
        local color = isComment and self.syntaxColors.comment or self.syntaxColors.string

        line.multilineAffected = color

        local contents = ""

        local foundClose = false

        while j <= #line.string do
          contents = contents .. line.string:sub(j, j)
          j = j + 1
          if line.string:sub(j - #multilineEnd, j - 1) == "]]" then
            foundClose = true
            line.multilineAffected = nil
            break
          end
        end

        line.text:add({ color, contents }, lastX)
        lastX = lastX + self.font:getWidth(contents)

        goto foundword

      elseif line.string:sub(j, j + 1) == "//" then

        local commentContent = ""
        while j <= #line.string do
          commentContent = commentContent .. line.string:sub(j, j)
          j = j + 1
        end

        line.text:add({ self.syntaxColors.comment, commentContent }, lastX)
        lastX = lastX + self.font:getWidth(commentContent)

        goto foundword
      end

      for word, color in pairs(self.syntaxColors.words) do
        if line.string:sub(j, j + #word - 1) == word and not line.string:sub(j + #word, j + #word):find("[%w]") and
            not line.string:sub(j - 1, j - 1):find("[%w]") then
          line.text:add({ color, word }, lastX)
          lastX = lastX + self.font:getWidth(word)
          j = j + #word
          goto foundword
        end
      end

      line.text:add({ self.syntaxColors.identifier, char }, lastX)
      lastX = lastX + self.font:getWidth(char)

      j = j + 1
      ::foundword::
    end

    line.totalWidth = lastX

    if not foundMultilineStart and line.hasMultilineStart then
      line.hasMultilineStart = false
      line.multilineAffected = nil
    end
  else
    line.text:add(line.string)
    line.totalWidth = line.text:getWidth()
  end

  if i < #self.lines and
      (
      line.multilineAffected ~= self.lines[i + 1].multilineAffected or
          not line.multilineAffected and self.lines[i + 1].multilineEnd) then
    self:updateLine(i + 1)
  end
end

function editor:inputText(t, userAction)
  if self.selecting then self:eraseSelection() end
  if t:find("\n") then
    local lastLine = ""
    for i = 1, #t do
      local c = t:sub(i, i)
      if self.multiline and c == "\n" or i == #t then
        if i == #t then lastLine = lastLine .. c end
        self.lines[self.cursor.line].string = self:curLine():sub(1, self.cursor.col - 1) ..
            lastLine .. self:curLine():sub(self.cursor.col)
        self.cursor.col = self.cursor.col + #lastLine
        if c == "\n" then self:newLine() end
        self:updateLine()
        lastLine = ""
      elseif c ~= "\r" then
        lastLine = lastLine .. c
      end
    end
  else
    self.lines[self.cursor.line].string = self:curLine():sub(1, self.cursor.col - 1) ..
        t .. self:curLine():sub(self.cursor.col)
    self:updateLine()
    self.cursor.col = self.cursor.col + #t
    self.cursor.lastCol = self.cursor.col
  end
  self:flick()
  self:scrollIntoView()
end

function editor:newLine(userAction)
  local orig = self:curLine()
  local indent
  local newS = orig:sub(self.cursor.col)
  local line = {
    string = newS,
    text = lg.newText(self.font, newS)
  }
  if userAction then
    indent = orig:match("^(%s*)")
    line.string = indent .. line.string
  end
  table.insert(self.lines, self.cursor.line + 1, line)
  self.lines[self.cursor.line].string = self:curLine():sub(1, self.cursor.col - 1)
  self:updateLine()
  self.cursor.line = self.cursor.line + 1
  self:updateLine()
  if userAction then
    self.cursor.col = #indent + 1
  end
  self.cursor.lastCol = self.cursor.col
end

function editor:copy()
  love.system.setClipboardText(self:getSelectionString())
end

function editor:cut()
  self:copy()
  if self.selecting then self:eraseSelection() end
end

function editor:paste()
  self:inputText(love.system.getClipboardText())
end

function editor:selectAll()
  self.selecting = true
  self.cursor.line, self.cursor.col = 1, 1
  self.minSelection = self.cursor
  self.selectStart.line, self.selectStart.col = #self.lines, #self.lines[#self.lines].string + 1
  self.maxSelection = self.selectStart
end

function editor:textinput(t)
  self.lastText = self.lastText .. t
  self:inputText(t, true)
end

function editor:keypressed(k)
  local ctrlDown = love.keyboard.isDown("lctrl", "rctrl")
  local pLine, pCol = self.cursor.line, self.cursor.col
  local changedPos = false
  if k == "left" then
    if ctrlDown then
      self.cursor.col = self:getPrevWord(self.cursor.col)
    else
      self.cursor.col = self.cursor.col - 1
      if self.cursor.col < 1 then
        if self.cursor.line > 1 then
          self.cursor.line = self.cursor.line - 1
          self.cursor.col = #self:curLine() + 1
        else
          self.cursor.col = 1
        end
      end
    end
    self.cursor.lastCol = self.cursor.col
    changedPos = true
    self:flick()
  elseif k == "right" then
    if ctrlDown then
      self.cursor.col = self:getNextWord(self.cursor.col)
    else
      self.cursor.col = self.cursor.col + 1
      if self.cursor.col > #self:curLine() + 1 then
        if self.cursor.line < #self.lines then
          self.cursor.line = self.cursor.line + 1
          self.cursor.col = 1
        else
          self.cursor.col = #self:curLine() + 1
        end
      end
    end
    self.cursor.lastCol = self.cursor.col
    changedPos = true
    self:flick()
  elseif k == "up" then
    if self.cursor.line == 1 then
      if self.cursor.col ~= 1 then
        self.cursor.col = 1
        self.cursor.lastCol = self.cursor.col
      end
    else
      self.cursor.line = self.cursor.line - 1
      self.cursor.col = self.cursor.lastCol
      if self.cursor.col > #self:curLine() + 1 then
        self.cursor.col = #self:curLine() + 1
      end
    end
    changedPos = true
    self:flick()
  elseif k == "down" then
    if self.cursor.line == #self.lines then
      self.cursor.col = #self:curLine() + 1
      self.cursor.lastCol = self.cursor.col
    else
      self.cursor.line = self.cursor.line + 1
      self.cursor.col = self.cursor.lastCol
      if self.cursor.col > #self:curLine() + 1 then
        self.cursor.col = #self:curLine() + 1
      end
    end
    changedPos = true
    self:flick()
  elseif k == "home" then
    if ctrlDown then
      self.cursor.line = 1
    end
    self.cursor.col = 1
    self.cursor.lastCol = self.cursor.col
    changedPos = true
    self:flick()
  elseif k == "end" then
    if ctrlDown then
      self.cursor.line = #self.lines
    end
    self.cursor.col = #self:curLine() + 1
    self.cursor.lastCol = self.cursor.col
    changedPos = true
    self:flick()
  elseif self.multiline and (k == "return" or k == "kpenter") then
    if self.selecting then self:eraseSelection() end
    self:newLine(true)
    if self.autoIndent then
      for _, p in ipairs(autoIndentPatterns) do
        if self.lines[self.cursor.line - 1].string:match(p) then
          self.lines[self.cursor.line].string = (" "):rep(self.tabSize) .. self:curLine()
          self.cursor.col = self.cursor.col + self.tabSize
          self:updateLine()
          break
        end
      end
    end
    self:flick()
  elseif k == "tab" and self.indentOnTab then
    self:inputText((" "):rep(self.tabSize))
  elseif k == "backspace" then
    if self.selecting then
      self:eraseSelection()
    elseif self.cursor.col > 1 then
      self.lines[self.cursor.line].string = self:curLine():sub(1, self.cursor.col - 2) ..
          self:curLine():sub(self.cursor.col)
      self:updateLine()
      self.cursor.col = self.cursor.col - 1
    elseif self.cursor.line > 1 then
      local deletedLine = table.remove(self.lines, self.cursor.line)
      deletedLine.text:release()
      self.cursor.line = self.cursor.line - 1
      self.cursor.col = #self:curLine() + 1
      self.lines[self.cursor.line].string = self:curLine() .. deletedLine.string
      self:updateLine()
    end
    self:flick()
  elseif k == "delete" then
    if self.selecting then
      self:eraseSelection()
    elseif self.cursor.col < #self:curLine() + 1 then
      self.lines[self.cursor.line].string = self:curLine():sub(1, self.cursor.col - 1) ..
          self:curLine():sub(self.cursor.col + 1)
      self:updateLine()
    elseif self.cursor.line < #self.lines then
      local deletedLine = table.remove(self.lines, self.cursor.line + 1)
      deletedLine.text:release()
      self.lines[self.cursor.line].string = self:curLine() .. deletedLine.string
      self:updateLine()
    end
    self:flick()
  elseif k == "x" and ctrlDown then
    self:cut()
  elseif k == "c" and ctrlDown then
    self:copy()
  elseif k == "v" and ctrlDown then
    self:paste()
  elseif k == "d" and ctrlDown and self.multiline then
    table.insert(self.lines, self.cursor.line, { string = self:curLine(), text = lg.newText(self.font, self:curLine()) })
  elseif k == "a" and ctrlDown then
    self:selectAll()
  end
  if self.useMacros then
    for _, m in ipairs(macros) do
      if m.triggerKey == k and m.condition(self) then
        m.action(self)
        self.lastText = ""
        return
      end
    end
  end
  self.lastText = ""
  if changedPos then
    if love.keyboard.isDown("lshift", "rshift") then
      if not self.selecting then
        self.selectStart.line = pLine
        self.selectStart.col = pCol
      end
      self.minSelection = self.cursor < self.selectStart and self.cursor or self.selectStart
      self.maxSelection = self.cursor < self.selectStart and self.selectStart or self.cursor
      self.selecting = true
    else
      self.selecting = false
    end
  end
  self:scrollIntoView()
end

function editor:getMousePos(x, y)
  x = x - self.x - self.textX
  y = y - self.y - self.textY
  local l = clamp(math.ceil(y / self.font:getHeight()), 1, #self.lines)
  local line = self.lines[l].string
  local retCol = #line + 1
  for i = 1, #line do
    local rightX = self.font:getWidth(line:sub(1, i))
    if x <= rightX then
      if x > (self.font:getWidth(line:sub(1, i - 1)) + rightX) / 2 then
        retCol = i + 1
      else
        retCol = i
      end
      break
    end
  end
  return l, retCol
end

function editor:onDown(x, y, b)
  if b == 1 then
    self.selecting = false
    local l, c = self:getMousePos(x, y)
    if l then
      self.cursor.line, self.cursor.col = l, c
      self.selectStart.line, self.selectStart.col = l, c
      if l == self.lastClick.line and c == self.lastClick.col and
          love.timer.getTime() - self.lastClickTime <= self.doubleClickTime then
        self.selecting = true
        self.cursor.col = self:getNextWord(c)
        self.cursor.col = self.cursor.col == #self:curLine() + 1 and self.cursor.col or self.cursor.col - 1
        self.selectStart.col = self:getPrevWord(c)
        self.minSelection = self.selectStart
        self.maxSelection = self.cursor
      end
      self.lastClick.line, self.lastClick.col = l, c
      self.lastClickTime = love.timer.getTime()
      self:flick()
    end
    SetCursor(love.mouse.getSystemCursor("ibeam"))
    self.lastText = ""
  end
end

function editor:onMove(x, y)
  if self.down then
    self.selecting = true
    local l, c = self:getMousePos(x, y)
    if l then
      self.cursor.line, self.cursor.col = l, c
      self.minSelection = self.cursor < self.selectStart and self.cursor or self.selectStart
      self.maxSelection = self.cursor < self.selectStart and self.selectStart or self.cursor
    end
  end
  if self.over then
    SetCursor(love.mouse.getSystemCursor("ibeam"))
  end
end

function editor:onFocus()
  self:flick()
end

function editor:onLoseFocus()
  self.selecting = false
end

function editor:onKeyboardFocus()
  self:selectAll()
end

function editor:onRightClick()
  OpenPopupMenu {
    { text = "Cut", action = function()
      self:cut()
    end },
    { text = "Copy", action = function()
      self:copy()
    end },
    { text = "Paste", enabled = love.system.getClipboardText() ~= "", action = function()
      self:paste()
    end },
    { separator = true },
    { text = "Select All", action = function()
      self:selectAll()
    end },
  }
end

function editor:eraseSelection()
  if self.minSelection.line == self.maxSelection.line then
    self.lines[self.cursor.line].string = self:curLine():sub(1, self.minSelection.col - 1) ..
        self:curLine():sub(self.maxSelection.col)
    self:updateLine()
  else
    self.lines[self.minSelection.line].string = self.lines[self.minSelection.line].string:sub(1,
      self.minSelection.col - 1) .. self.lines[self.maxSelection.line].string:sub(self.maxSelection.col)
    self:updateLine(self.minSelection.line)
    self.lines[self.maxSelection.line].string = self.lines[self.maxSelection.line].string:sub(self.maxSelection.col)
    table.remove(self.lines, self.maxSelection.line).text:release()
  end
  for i = self.minSelection.line + 1, self.maxSelection.line - 1 do
    table.remove(self.lines, self.minSelection.line + 1).text:release()
  end
  if self.cursor ~= self.minSelection then
    self.cursor.col, self.cursor.line = self.minSelection.col, self.minSelection.line
  end
  self.selecting = false
end

function editor:concatLines(start, finish)
  start = start or 1
  finish = finish or #self.lines

  local str = ""
  for i = start, finish do
    str = str .. self.lines[i].string .. (i < finish and "\n" or "")
  end

  return str
end

function editor:getString()
  return self:concatLines()
end

function editor:getSelectionString()
  if not self.selecting then
    return self:curLine()
  elseif self.minSelection.line == self.maxSelection.line then
    return self.lines[self.minSelection.line].string:sub(self.minSelection.col, self.maxSelection.col - 1)
  else
    local conc = self:concatLines(self.minSelection.line + 1, self.maxSelection.line - 1)
    return self.lines[self.minSelection.line].string:sub(self.minSelection.col) ..
        "\n" ..
        conc ..
        (self.maxSelection.line > self.minSelection.line + 1 and "\n" or "") ..
        self.lines[self.maxSelection.line].string:sub(1, self.maxSelection.col - 1)
  end
end

function editor:textToScreen(line, col)
  return self.font:getWidth(self.lines[line].string:sub(1, col - 1)) + 1,
      (line - 1) * self.font:getHeight()
end

function editor:getScreenCursorPosition()
  return self:textToScreen(self.cursor.line, self.cursor.col)
end

function editor:draw()
  lg.push("all")
  lg.translate(self.x, self.y)
  PushStencil(self.stencilFunc)

  lg.push()
  lg.translate(self.textX, self.textY)

  for _, underline in ipairs(self.underlines.list) do
    local fromDx, fromDy = self:textToScreen(underline.fromLine, underline.fromColumn)
    local toDx, toDy = self:textToScreen(underline.toLine, underline.toColumn + 1)
    fromDy = fromDy + self.font:getHeight()
    toDy = toDy + self.font:getHeight()
    if fromDx == toDx then
      toDx = toDx + self.font:getWidth(" ")
    end
    if not underline._quad then
      underline._quad = lg.newQuad(0, 0, toDx - fromDx, underlineImage:getHeight(), underlineImage:getDimensions())
    end
    lg.setColor(underline.color)
    lg.draw(underlineImage, underline._quad, fromDx, fromDy - underlineImage:getHeight())
  end

  for i, l in ipairs(self.lines) do
    local dy = (i - 1) * self.font:getHeight()
    if self.selecting then
      if i >= self.minSelection.line and i <= self.maxSelection.line then
        lg.setColor(self.selectionColor)
        local startX, endX = 0, l.totalWidth
        if i == self.minSelection.line then
          startX = self.font:getWidth(self.lines[i].string:sub(1, self.minSelection.col - 1))
        end
        if i == self.maxSelection.line then
          endX = self.font:getWidth(self.lines[i].string:sub(1, self.maxSelection.col - 1))
        end
        if i < self.maxSelection.line and self.minSelection.line ~= self.maxSelection.line then
          endX = endX + self.font:getWidth(" ")
        end
        lg.rectangle("fill", startX, dy, endX - startX, self.font:getHeight())
      end
    end
    lg.setColor(self.textColor or white)
    lg.draw(l.text, 0, dy)
  end

  if self.focused and math.floor(love.timer.getTime() * self.flickSpeed - self.flickTime) % 2 == 0 then
    lg.setColor(self.syntaxColors and self.syntaxColors.identifier or white)
    lg.setLineStyle("rough")
    lg.setLineWidth(cursorWidth)
    local dx, dy = self:getScreenCursorPosition()
    lg.line(dx, dy, dx, dy + self.font:getHeight())
  end

  lg.setStencilTest()
  lg.pop()
  PopStencil(self.stencilFunc)
  lg.pop()

  if self.drawBorder then
    lg.setColor(white)
    lg.setLineWidth(1)
    lg.rectangle("line", self.x, self.y, self.w, self.h, 3)
  end
end

function editor:getPrevWord(i)
  local line = self:curLine()
  for j = i - 2, 1, -1 do
    if line:sub(j, j):find("[^%w]") then
      return j + 1
    end
  end
  return 1
end

function editor:getNextWord(i)
  local line = self:curLine()
  for j = i + 1, #line do
    if line:sub(j, j):find("[^%w]") then
      return j + 1
    end
  end
  return #line + 1
end

function editor:scrollIntoView()
  local dx, dy = self:getScreenCursorPosition()

  if -self.textX > dx then
    self.textX = -(dx - defaultTextPadding)
  elseif -self.textX + self.w < dx then
    self.textX = -(dx - self.w + defaultTextPadding)
  end

  if -self.textY > dy then
    self.textY = -(dy - defaultTextPadding)
  elseif -self.textY + self.h < dy + self.font:getHeight() then
    self.textY = -(dy - self.h + self.font:getHeight() + defaultTextPadding)
  end
end

return editor
