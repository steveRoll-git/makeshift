---@type SyntaxStylesTable
local style = {
  patternStyles = {
    { "//.*$",    "comment" },

    { '".*"',     "string" },

    { "%d%.?%d*", "number" },

    { "while",    "keyword" },
    { "if",       "keyword" },
    { "else",     "keyword" },
    { "elseif",   "keyword" },
    { "on",       "keyword" },

    { "true",     "constant" },
    { "false",    "constant" },
    { "this",     "constant" },
  },
  multilineStyles = {}
}

return style
