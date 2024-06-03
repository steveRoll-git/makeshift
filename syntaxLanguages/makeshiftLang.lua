---@type SyntaxStylesTable
local style = {
  patternStyles = {
    { "//.*$",     "comment" },

    { '".*"',      "string" },

    { "%d+%.?%d*", "number",   word = true },

    { "while",     "keyword",  word = true },
    { "if",        "keyword",  word = true },
    { "else",      "keyword",  word = true },
    { "elseif",    "keyword",  word = true },
    { "on",        "keyword",  word = true },

    { "true",      "constant", word = true },
    { "false",     "constant", word = true },
    { "this",      "constant", word = true },
  },
  multilineStyles = {}
}

return style
