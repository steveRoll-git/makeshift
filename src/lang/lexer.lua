local lookupify = require "util.lookupify"

local keywords = lookupify {
  "if", "else", "elseif", "while", "on", "true", "false", "var", "this"
}

local groupPunctuation = lookupify {
  "==", "!=", ">=", "<=", "+=", "-=", "*=", "/=", "&&", "||", ".."
}

---@alias TokenKind
---| "EOF"
---| "punctuation"
---| "number"
---| "string"
---| "keyword"
---| "identifier"
---| "singleComment"

---@class Token
---@field kind TokenKind
---@field value string
---@field line number
---@field column number

---@class SyntaxError
---@field error true
---@field source Script
---@field fromLine number
---@field fromColumn number
---@field toLine number
---@field toColumn number
---@field message string

---@class Lexer
local Lexer = {}
Lexer.__index = Lexer

---@param code string
---@param sourceScript? Script
function Lexer.new(code, sourceScript)
  local self = setmetatable({}, Lexer)
  self:init(code, sourceScript)
  return self
end

---@param code string
---@param sourceScript? Script
function Lexer:init(code, sourceScript)
  self.code = code
  self.sourceScript = sourceScript
  self.index = 1
  self.column = 1
  self.line = 1
  self.prevColumn = 1
  self.prevLine = 1
  self.reachedEnd = #code == 0
  ---@type SyntaxError[]
  self.errorStack = {}
end

---Returns the next string of the given length.
---@param length number
---@return string
function Lexer:lookAhead(length)
  return self.code:sub(self.index, self.index + length - 1)
end

function Lexer:curChar()
  return self.code:sub(self.index, self.index)
end

---Advances by the given number of characters (or 1).
---@param times? number
function Lexer:advanceChar(times)
  if self.reachedEnd then
    return
  end

  times = times or 1
  for i = 1, times do
    self.index = self.index + 1
    if self.index > #self.code then
      self.reachedEnd = true
      return
    end
    local c = self:curChar()
    if c == "\n" then
      self.lastLineEnd = self.column
      self.column = 0
      self.line = self.line + 1
    else
      self.column = self.column + 1
    end
  end
end

---Reads and returns the next token.
---@return Token
function Lexer:nextToken()
  -- skip past spaces and newlines
  while not self.reachedEnd and self:curChar():find("%s") do
    self:advanceChar()
  end

  self.prevColumn = self.column
  self.prevLine = self.line

  if self.reachedEnd then
    return {
      kind = "EOF"
    }
  end

  if self:lookAhead(2) == "//" then
    self:advanceChar(2)
    local start = self.index
    while self:curChar() ~= "\n" do
      self:advanceChar()
    end
    self:advanceChar()
    return {
      kind = "singleComment",
      value = self.code:sub(start, self.index - 2),
      line = self.prevLine,
      column = self.prevColumn,
    }
  end

  if self:curChar() == '"' then
    local start = self.index + 1
    self:advanceChar()
    while self:curChar() ~= '"' do
      self:advanceChar()
      if self:curChar() == "\n" or self.reachedEnd then
        return self:syntaxError("unfinished string")
      end
    end
    self:advanceChar()
    return {
      kind = "string",
      value = self.code:sub(start, self.index - 2),
      line = self.prevLine,
      column = self.prevColumn,
    }
  end

  if self:curChar():find("[%a_]") then
    local start = self.index
    while self:curChar():find("[%w_]") do
      self:advanceChar()
    end
    local value = self.code:sub(start, self.index - 1)
    return {
      kind = keywords[value] and "keyword" or "identifier",
      value = value,
      line = self.prevLine,
      column = self.prevColumn,
    }
  end

  if self:curChar():find("%d") then
    local start = self.index
    while self:curChar():find("[%d%.]") do
      self:advanceChar()
    end
    return {
      kind = "number",
      value = self.code:sub(start, self.index - 1),
      line = self.prevLine,
      column = self.prevColumn,
    }
  end

  if self:curChar():find("%p") then
    local start = self.index
    while groupPunctuation[self.code:sub(start, self.index + 1)] do
      self:advanceChar()
    end
    self:advanceChar()
    return {
      kind = "punctuation",
      value = self.code:sub(start, self.index - 1),
      line = self.prevLine,
      column = self.prevColumn,
    }
  end

  return self:syntaxError(("unexpected character: %q"):format(self:curChar()))
end

---Returns a token to be returned on errors.
---@return Token
function Lexer:errorToken()
  return {
    kind = "error",
    value = "",
    line = self.prevLine,
    column = self.prevColumn,
  }
end

---Creates a syntax error table and pushes it onto the error stack, and returns an error token.
---@param message string
---@return Token
function Lexer:syntaxError(message)
  local toLine, toColumn = self.line, self.column
  if toLine ~= self.prevLine then
    toLine = self.prevLine
    toColumn = self.lastLineEnd
  end
  ---@type SyntaxError
  local err = {
    error = true,
    source = self.sourceScript,
    fromLine = self.prevLine,
    fromColumn = self.prevColumn,
    toLine = toLine,
    toColumn = toColumn,
    message = message
  }
  table.insert(self.errorStack, err)
  return self:errorToken()
end

return Lexer
