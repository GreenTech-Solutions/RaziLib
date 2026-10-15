local Core = require("__razi_lib__/lib/core")
local Collections = {}

function Collections.contains(list, value, key)
  for _, entry in pairs(list or {}) do
    if (key and entry[key] or entry) == value then return true end
  end
  return false
end

function Collections.append_unique(list, value, key)
  list = list or {}
  if not Collections.contains(list, key and value[key] or value, key) then
    list[#list + 1] = value
  end
  return list
end

function Collections.remove(list, predicate)
  local filtered = {}
  for _, value in pairs(list or {}) do
    local remove = type(predicate) == "function" and predicate(value) or value == predicate
    if not remove then filtered[#filtered + 1] = value end
  end
  return filtered
end

function Collections.index_by(list, key_or_function)
  local indexed = {}
  for _, value in pairs(list or {}) do
    local key = type(key_or_function) == "function" and key_or_function(value) or value[key_or_function]
    if key ~= nil then indexed[key] = value end
  end
  return indexed
end

function Collections.map(list, mapper)
  local mapped = {}
  for index, value in ipairs(list or {}) do mapped[index] = mapper(value, index) end
  return mapped
end

-- Stable array deduplication: no hash-table iteration reordering.
-- 'key' accepts a field name or identity callback for records.
function Collections.unique(list, key)
  local result, seen = {}, {}
  for _, entry in ipairs(list or {}) do
    local identity = entry
    if type(key) == "function" then identity = key(entry)
    elseif key then identity = entry[key] end
    if identity == nil then identity = entry end
    if not seen[identity] then
      seen[identity] = true
      result[#result + 1] = entry
    end
  end
  return result
end

function Collections.copy(list)
  return Core.deepcopy(list or {})
end

return Collections
