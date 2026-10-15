-- Technology-graph algorithms shared by Factorio data-stage consumers.
-- No automatic gameplay edits, mod references or mutable module-global caches.
local Graph = {}

-- Iterative traversal avoids Lua stack exhaustion on very large tech packs.
-- Like Factorio's prerequisite relation, a node reaches itself even when it
-- is an optional/missing source prototype.
function Graph.reaches(technologies, start, wanted)
  if not start or not wanted then return false end
  if start == wanted then return true end
  local visited = {}
  local pending = {start}
  while #pending > 0 do
    local current = pending[#pending]
    pending[#pending] = nil
    if not visited[current] then
      visited[current] = true
      local node = technologies and technologies[current]
      for _, parent in ipairs(node and node.prerequisites or {}) do
        if parent == wanted then return true end
        if not visited[parent] then pending[#pending + 1] = parent end
      end
    end
  end
  return false
end

-- Detect only real existing-node cycles. Return one ordered witness cycle,
-- without the repeated closing node, for safe source-specific repair policy.
-- The explicit DFS stack preserves the old deterministic sorted-root order.
function Graph.find_cycle(technologies)
  technologies = technologies or {}
  local roots = {}
  for name in pairs(technologies) do roots[#roots + 1] = name end
  table.sort(roots)
  local state, position = {}, {}
  for _, root in ipairs(roots) do
    if not state[root] then
      local stack = {{name = root, next_parent = 1}}
      state[root] = 1
      position[root] = 1
      while #stack > 0 do
        local frame = stack[#stack]
        local node = technologies[frame.name]
        local parents = node and node.prerequisites or {}
        local parent = parents[frame.next_parent]
        if parent == nil then
          state[frame.name] = 2
          position[frame.name] = nil
          stack[#stack] = nil
        else
          frame.next_parent = frame.next_parent + 1
          if technologies[parent] then
            if state[parent] == 1 then
              local cycle = {}
              for i = position[parent], #stack do
                cycle[#cycle + 1] = stack[i].name
              end
              return cycle
            elseif not state[parent] then
              state[parent] = 1
              stack[#stack + 1] = {name = parent, next_parent = 1}
              position[parent] = #stack
            end
          end
        end
      end
    end
  end
end

-- Add a direct edge only if neither a cycle nor an already-implied
-- prerequisite would result. Returns true only when a new edge was added.
-- Consumer-owned policy (active/hidden source checks) remains in the caller.
function Graph.add_prerequisite(technologies, target, parent)
  local node = technologies and technologies[target]
  if not (node and technologies[parent]) or target == parent
    or Graph.reaches(technologies, parent, target)
    or Graph.reaches(technologies, target, parent) then return false end
  node.prerequisites = node.prerequisites or {}
  node.prerequisites[#node.prerequisites + 1] = parent
  return true
end

-- Sorted, deduplicated lookup of the real technologies unlocking each recipe.
-- Rebuild after edits; no cache can leak between data-stage source passes.
function Graph.unlock_index(technologies)
  local index = {}
  for name, node in pairs(technologies or {}) do
    local encountered = {}
    for _, effect in ipairs(node.effects or {}) do
      local recipe = effect.type == "unlock-recipe" and effect.recipe
      if recipe and not encountered[recipe] then
        encountered[recipe] = true
        index[recipe] = index[recipe] or {}
        index[recipe][#index[recipe] + 1] = name
      end
    end
  end
  for _, unlockers in pairs(index) do table.sort(unlockers) end
  return index
end

function Graph.first_unlock(technologies, recipe, visible_only)
  for _, name in ipairs(Graph.unlock_index(technologies)[recipe] or {}) do
    local node = technologies[name]
    if not visible_only or (node.enabled ~= false and not node.hidden) then
      return name
    end
  end
end

return Graph
