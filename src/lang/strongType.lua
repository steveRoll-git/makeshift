local function getType(value)
  local mt = getmetatable(value)
  if mt and mt.__typeName then
    return mt.__typeName
  end
  return type(value)
end

---@class StrongTypeField
---@field type string
---@field getter? fun(any): any
---@field setter? fun(any, any)

---@class StrongTypeInstance

---@class StrongType
---@field name string
---@field fields {[string]: StrongTypeField}
---@field parent StrongType?
local StrongType = {}
StrongType.__index = StrongType

---@param name string
---@param fields {[string]: StrongTypeField}
---@param parent? StrongType
function StrongType.new(name, fields, parent)
  local self = setmetatable({}, StrongType)
  self:init(name, fields, parent)
  return self
end

---@param name string
---@param fields {[string]: StrongTypeField}
---@param parent? StrongType
function StrongType:init(name, fields, parent)
  self.name = name
  self.fields = fields
  self.parent = parent

  self.indexFunction = function(obj, key)
    local actual = getmetatable(obj).__actualValue
    local field = self:getField(key)
    if field then
      if field.getter then
        return field.getter(actual)
      elseif field.setter then
        error(("Field %q is write-only"):format(key), 2)
      else
        return actual[key]
      end
    else
      error(("Type %s doesn't have a field named %q"):format(self.name, key), 2)
    end
  end

  self.newIndexFunction = function(obj, key, value)
    local actual = getmetatable(obj).__actualValue
    local field = self:getField(key)
    if field then
      if getType(value) == field.type then
        if field.setter then
          field.setter(actual, value)
        elseif field.getter then
          error(("Field %q is read-only"):format(key), 2)
        else
          actual[key] = value
        end
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

---Returns this type's field of this name, if it exists.
---@param name string
---@return StrongTypeField?
function StrongType:getField(name)
  if self.fields[name] then
    return self.fields[name]
  end
  if self.parent then
    return self.parent:getField(name)
  end
  return nil
end

---Creates a new instance of this StrongType.
---@param init table
---@return StrongTypeInstance
function StrongType:instance(init)
  local actual = init or {}
  return setmetatable({}, {
    __actualValue = actual,
    __typeName = self.name,
    __index = self.indexFunction,
    __newindex = self.newIndexFunction,
  })
end

return StrongType
