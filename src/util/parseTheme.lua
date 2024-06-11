local parseColor = require "util.parseColor"

---@alias Color number[]

---@alias UnparsedTheme table<string, string | table<string, string>>

---@class Theme
---@field backgroundInactive Color
---@field backgroundActive Color
---@field backgroundError Color
---@field backgroundBright Color
---@field backgroundOverlay Color
---@field foreground Color
---@field foregroundActive Color
---@field foregroundDimmed Color
---@field foregroundError Color
---@field elementHovered Color
---@field elementPressed Color
---@field elementNeutral Color
---@field outline Color
---@field outlineActive Color
---@field codeEditor CodeEditorTheme

---@class CodeEditorTheme
---@field default Color
---@field comment Color
---@field string Color
---@field number Color
---@field constant Color
---@field lineNumber Color
---@field underlineError Color
---@field lineBackgroundError Color

---@param t UnparsedTheme
local function parseThemeTable(t)
  local new = {}
  for k, v in pairs(t) do
    if type(v) == "string" then
      new[k] = { parseColor(v) }
    else
      new[k] = parseThemeTable(v)
    end
  end
  return new
end

---Parses a theme table with string color codes into a theme table with the actual colors.
---@param t UnparsedTheme
---@return Theme
return function(t)
  return parseThemeTable(t)
end
