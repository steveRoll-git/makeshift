local hexToColor = require "util.hexToColor"

return {
  default = { hexToColor(0xd4d4d4) },
  comment = { hexToColor(0x6a9955) },
  string = { hexToColor(0xce9178) },
  number = { hexToColor(0xb5cea8) },
  keyword = { hexToColor(0xc586c0) },
  constant = { hexToColor(0x569cd6) },
}
