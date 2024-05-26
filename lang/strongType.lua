local function getType(value)
  local mt = getmetatable(value)
  if mt and mt.__typeName then
    return mt.__typeName
  end
  return type(value)
end

---@class StrongTypeField
---@field type string

---@class StrongType
---@field name string
---@field fields {[string]: StrongTypeField}
local strongType = {}
strongType.__index = strongType

---@param name string
---@param fields {[string]: StrongTypeField}
function strongType.new(name, fields)
  local self = setmetatable({}, strongType)
  self:init(name, fields)
  return self
end

---@param name string
---@param fields {[string]: StrongTypeField}
function strongType:init(name, fields)
  self.name = name
  self.fields = fields

  self.indexFunction = function(obj, key)
    local actual = getmetatable(obj).__actualValue
    if self.fields[key] then
      return actual[key]
    else
      error(("Type %s doesn't have a field named %q"):format(self.name, key), 2)
    end
  end

  self.newIndexFunction = function(obj, key, value)
    local actual = getmetatable(obj).__actualValue
    if self.fields[key] then
      if getType(value) == self.fields[key].type then
        actual[key] = value
      else
        error(
          ("Field %q is of type %s - can't assign value of type %s to it"):format(
            key,
            self.fields[key].type,
            getType(value)), 2)
      end
    else
      error(("Type %s doesn't have a field named %q"):format(self.name, key), 2)
    end
  end
end

function strongType:instance(init)
  local actual = init or {}
  return setmetatable({}, {
    __actualValue = actual,
    __typeName = self.name,
    __index = self.indexFunction,
    __newindex = self.newIndexFunction,
  })
end

return strongType
