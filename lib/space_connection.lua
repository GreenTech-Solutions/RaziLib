local SpaceConnection = {}

local function connections()
  return data.raw["space-connection"]
end

function SpaceConnection.remove(name)
  local group = connections()
  if group then group[name] = nil end
end

function SpaceConnection.remove_between(location_a, location_b)
  local group = connections()
  if not group then return end
  for name, connection in pairs(group) do
    local from = connection and connection.from
    local to = connection and connection.to
    if (from == location_a and to == location_b) or (from == location_b and to == location_a) then
      group[name] = nil
    end
  end
end

function SpaceConnection.remove_all()
  local group = connections()
  if not group then return end
  for name in pairs(group) do group[name] = nil end
end

function SpaceConnection.remove_except_locations(locations)
  local group = connections()
  if not group then return end
  local keep = {}
  for _, name in pairs(locations or {}) do keep[name] = true end
  for name, connection in pairs(group) do
    if not (connection and (keep[connection.from] or keep[connection.to])) then group[name] = nil end
  end
end

return SpaceConnection
