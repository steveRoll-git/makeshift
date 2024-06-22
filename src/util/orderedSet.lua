---@class OrderedSet
---@field private lookup table<any, number>
---@field list any[]
---@field private count number
local OrderedSet = {}
OrderedSet.__index = OrderedSet

function OrderedSet.new(elements)
  local self = setmetatable({}, OrderedSet)
  self.lookup = {}
  self.list = {}
  self.count = 0
  if elements then
    for i, e in ipairs(elements) do
      self:add(e)
    end
  end
  return self
end

---Adds the item into the set's end.
---@param item any
function OrderedSet:add(item)
  assert(not self.lookup[item], "added item is already inside the set")

  self.count = self.count + 1
  self.list[self.count] = item
  self.lookup[item] = self.count
end

---Inserts the item at the specified index.
---@param index number
---@param item any
function OrderedSet:insertAt(index, item)
  assert(not self.lookup[item], "added item is already inside the set")
  assert(index >= 1 and index <= self.count + 1)

  for i = self.count, index, -1 do
    self.list[i + 1] = self.list[i]
    self.lookup[self.list[i + 1]] = i + 1
  end

  self.count = self.count + 1
  self.list[index] = item
  self.lookup[item] = index
end

---Removes the item at `index` from the set.
---@param index number
function OrderedSet:removeAt(index)
  assert(index >= 1 and index <= self.count, "index is out of range")

  local item = self.list[index]
  for i = index, self.count do
    self.list[i] = self.list[i + 1]
    if i < self.count then
      self.lookup[self.list[i]] = i
    end
  end
  self.lookup[item] = nil
  self.count = self.count - 1
end

---Removes the item from the set.
---@param item any
function OrderedSet:remove(item)
  assert(self.lookup[item], "item is not in the set")
  self:removeAt(self.lookup[item])
end

---Returns the index of the item in the set.
---@param item any
---@return number
function OrderedSet:getIndex(item)
  assert(self.lookup[item], "item is not in the set")

  return self.lookup[item]
end

---Returns the item at `index`
---@param index number
---@return any
function OrderedSet:itemAt(index)
  return self.list[index]
end

---Returns the last item in the set.
---@return any
function OrderedSet:last()
  return self.list[self.count]
end

---Returns whether `item` is in this set.
---@param item any
---@return boolean
function OrderedSet:has(item)
  return not not self.lookup[item]
end

---Returns the number of items currently in the set.
---@return number
function OrderedSet:getCount()
  return self.count
end

return OrderedSet
