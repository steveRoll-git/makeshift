local insertAll = require "util.insertAll"
local uidToHex = require "util.uidToHex"

---@alias LuaCodeOutput {string: string, line: number?, appendNewline: boolean?}[]

local translateBinaryOperators = {
  ["!="] = "~=",
  ["&&"] = "and",
  ["||"] = "or",
}

local translateUnaryOperators = {
  ["!"] = "not",
}

---@type table<string, fun(t: table, s: Script): LuaCodeOutput>
local output = {}

---Returns the lua code for the given tree.
---@param tree table
---@param script Script
---@return LuaCodeOutput
local function translate(tree, script)
  return output[tree.kind](tree, script)
end

function output.stringLiteral(tree, script)
  return { { string = ("%q"):format(tree.value), line = tree.line } }
end

function output.number(tree, script)
  return { { string = tree.value, line = tree.line } }
end

function output.boolean(tree, script)
  return { { string = tree.value, line = tree.line } }
end

function output.identifier(tree, script)
  return { { string = tree.value, line = tree.line } }
end

function output.thisValue(tree, script)
  return { { string = "self" } }
end

function output.objectIndex(tree, script)
  local result = {}

  insertAll(result, translate(tree.object, script))

  local index = translate(tree.index, script)
  index[1].string = "[" .. index[1].string
  insertAll(result, index)
  table.insert(result, { string = "]", line = tree.line })

  return result
end

function output.functionCall(tree, script)
  local result = {}

  insertAll(result, translate(tree.object, script))
  result[#result].appendNewline = false
  table.insert(result, { string = "(", line = tree.line })
  for i, p in ipairs(tree.params) do
    insertAll(result, translate(p, script))
    if i < #tree.params then
      table.insert(result, { string = "," })
    end
  end
  table.insert(result, { string = ")" })

  return result
end

function output.assignment(tree, script)
  local result = {}

  insertAll(result, translate(tree.object, script))
  table.insert(result, { string = "=" })
  insertAll(result, translate(tree.value, script))

  return result
end

function output.compoundAssignment(tree, script)
  return output.assignment({
    object = tree.object,
    value = {
      kind = "binaryOperator",
      operator = tree.operator:sub(1, 1),
      lhs = tree.object,
      rhs = tree.value,
      line = tree.line,
    }
  }, script)
end

function output.ifStatement(tree, script)
  local result = {}

  table.insert(result, { string = "if" })
  insertAll(result, translate(tree.condition, script))
  table.insert(result, { string = "then" })
  insertAll(result, translate(tree.body, script))

  for _, e in ipairs(tree.elseIfs) do
    table.insert(result, { string = "elseif" })
    insertAll(result, translate(e.condition, script))
    table.insert(result, { string = "then" })
    insertAll(result, translate(e.body, script))
  end

  if tree.elseBody then
    table.insert(result, { string = "else" })
    insertAll(result, translate(tree.elseBody, script))
  end

  table.insert(result, { string = "end" })
  return result
end

function output.whileLoop(tree, script)
  local result = {}

  table.insert(result, { string = "while" })
  insertAll(result, translate(tree.condition, script))
  table.insert(result, { string = "do" })
  insertAll(result, translate(tree.body, script))
  local loopString = ("loop %s %d %d"):format(
    uidToHex(script.id),
    tree.startLine,
    tree.endLine)
  table.insert(result, {
    string = (" _yield('%s') end\n_yield('end%s')"):format(loopString, loopString)
  })

  return result
end

function output.localVariableDeclaration(tree, script)
  local result = {}

  table.insert(result, { string = ("local %s"):format(tree.name) })
  if tree.value then
    table.insert(result, { string = "=" })
    insertAll(result, translate(tree.value, script))
  end

  return result
end

function output.unaryOperator(tree, script)
  local result = {}
  table.insert(result, { string = translateUnaryOperators[tree.operator] or tree.operator, line = tree.line })
  insertAll(result, translate(tree.value, script))
  return result
end

function output.binaryOperator(tree, script)
  local result = {}

  local lhs = translate(tree.lhs, script)
  lhs[1].string = "(" .. lhs[1].string
  lhs[#lhs].string = lhs[#lhs].string .. ")"
  insertAll(result, lhs)

  table.insert(result, { string = translateBinaryOperators[tree.operator] or tree.operator, line = tree.line })

  local rhs = translate(tree.rhs, script)
  rhs[1].string = "(" .. rhs[1].string
  rhs[#rhs].string = rhs[#rhs].string .. ")"
  insertAll(result, rhs)

  return result
end

function output.block(tree, script)
  local result = {}
  for _, s in ipairs(tree.statements) do
    insertAll(result, translate(s, script))
  end
  return result
end

function output.eventHandler(tree, script)
  local result = {}
  table.insert(result, { string = ("function theObject:%s(%s)"):format(tree.eventName, table.concat(tree.params, ", ")) })
  insertAll(result, translate(tree.body, script))
  table.insert(result, { string = ("end") })
  return result
end

function output.objectCode(tree, script)
  local result = {}
  table.insert(result, { string = ("local theObject = {}") })
  for _, e in ipairs(tree.eventHandlers) do
    insertAll(result, translate(e, script))
  end
  table.insert(result, { string = ("return theObject") })
  return result
end

-- returns the resulting lua code, and a source map.
---@param tree table
---@param script Script
---@return string code
---@return table<number, number> sourceMap
local function finalOutput(tree, script)
  local resultString = ""
  local elements = translate(tree, script)
  local sourceMap = {}
  local currentLine = 1

  for _, e in ipairs(elements) do
    resultString = (e.appendNewline == false and "%s%s" or "%s%s\n"):format(resultString, e.string)
    if e.line then
      sourceMap[currentLine] = e.line
    end
    if e.appendNewline ~= false then
      currentLine = currentLine + 1
    end
  end

  return resultString, sourceMap
end

return finalOutput
