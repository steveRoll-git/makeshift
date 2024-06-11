local parseTheme = require "util.parseTheme"

return parseTheme {
  backgroundInactive = "#181818",
  backgroundActive = "#1f1f1f",
  backgroundBright = "#222222",
  backgroundError = "#691014",
  backgroundOverlay = "#000000d0",
  foreground = "#cccccc",
  foregroundDimmed = "#9d9d9d",
  foregroundActive = "#ffffff",
  foregroundError = "#ff0000",
  elementNeutral = "#434343",
  elementHovered = "#4f4f4f",
  elementPressed = "#5f5f5f",
  outline = "#2b2b2b",
  outlineActive = "#454545",
  codeEditor = {
    default = "#d4d4d4",
    comment = "#6a9955",
    string = "#ce9178",
    number = "#b5cea8",
    keyword = "#c586c0",
    constant = "#569cd6",
    lineNumber = "#6e6e6e",
    underlineError = "#f14c4c",
    lineBackgroundError = "#80000080"
  },
}
