local Core = require("__razi_lib__/lib/core")
local Prototype = require("__razi_lib__/lib/prototype")

local Technology = {}
local methods = {}

local science_codes = {
  R = "automation-science-pack", G = "logistic-science-pack",
  B = "chemical-science-pack", M = "military-science-pack",
  P = "production-science-pack", Y = "utility-science-pack",
  W = "space-science-pack", V = "metallurgic-science-pack",
  F = "electromagnetic-science-pack", A = "agricultural-science-pack",
  C = "cryogenic-science-pack", S = "promethium-science-pack",
}
local science_order = { "R", "G", "B", "M", "P", "Y", "W", "V", "F", "A", "C", "S" }

local function requested_name(self_or_name, maybe_name) return maybe_name or self_or_name end

function Technology.register_science(code, item_name, position)
  Core.assert_string(code, "science code")
  Core.assert_string(item_name, "science item")
  science_codes[code] = item_name
  for index, existing in ipairs(science_order) do
    if existing == code then table.remove(science_order, index) break end
  end
  table.insert(science_order, position or (#science_order + 1), code)
end

function Technology.get(self_or_name, maybe_name)
  return Prototype.get("technology", requested_name(self_or_name, maybe_name), methods)
end

function Technology.optional(self_or_name, maybe_name)
  return Prototype.optional("technology", requested_name(self_or_name, maybe_name), methods)
end

function Technology.exists(self_or_name, maybe_name)
  return Prototype.exists("technology", requested_name(self_or_name, maybe_name))
end

function Technology.first_existing(names)
  for _, name in ipairs(names or {}) do
    local technology = Technology.optional(name)
    if technology then return technology end
  end
  return nil
end

function Technology.first_existing_name(names)
  local technology = Technology.first_existing(names)
  return technology and technology._name or nil
end

function Technology.has_dependents(name)
  for _, technology in pairs(data.raw.technology or {}) do
    for _, prerequisite in ipairs(technology.prerequisites or {}) do
      if prerequisite == name then return true end
    end
  end
  return false
end

function Technology.clone(self_or_from, from_or_into, maybe_into)
  local from = maybe_into and from_or_into or self_or_from
  local into = maybe_into or from_or_into
  Prototype.clone("technology", from, into)
  return Technology.get(into)
end

Technology.cloneInto = Technology.clone

local function unit(self)
  self._prototype.unit = self._prototype.unit or { count = 1, ingredients = {}, time = 30 }
  return self._prototype.unit
end

function methods:set_cost(count)
  unit(self).count_formula = nil
  unit(self).count = count
  return self
end

function methods:set_cost_formula(formula)
  unit(self).count = nil
  unit(self).count_formula = formula
  return self
end

function methods:set_time(seconds)
  unit(self).time = seconds
  return self
end

function methods:set_packs(packs)
  unit(self).ingredients = Core.deepcopy(packs)
  return self
end

function methods:set_colors(codes)
  local packs = {}
  for _, code in ipairs(science_order) do
    if codes:find(code, 1, true) then packs[#packs + 1] = { science_codes[code], 1 } end
  end
  return self:set_packs(packs)
end

function methods:add_pack(name, amount)
  local packs = unit(self).ingredients
  for _, pack in pairs(packs) do
    if (pack.name or pack[1]) == name then
      pack.amount = math.max(pack.amount or pack[2] or 0, amount or 1)
      pack[2] = nil
      return self
    end
  end
  packs[#packs + 1] = { name, amount or 1 }
  return self
end

function methods:has_pack(name)
  for _, pack in pairs(self._prototype.unit and self._prototype.unit.ingredients or {}) do
    if (pack.name or pack[1]) == name then return true end
  end
  return false
end

function methods:set_effects(effects) self._prototype.effects = Core.deepcopy(effects); return self end
function methods:set_prerequisites(prerequisites) self._prototype.prerequisites = Core.deepcopy(prerequisites); return self end

function methods:add_prerequisite(name)
  self._prototype.prerequisites = self._prototype.prerequisites or {}
  for _, prerequisite in pairs(self._prototype.prerequisites) do
    if prerequisite == name then return self end
  end
  self._prototype.prerequisites[#self._prototype.prerequisites + 1] = name
  return self
end

function methods:has_prerequisite(name)
  for _, prerequisite in pairs(self._prototype.prerequisites or {}) do
    if prerequisite == name then return true end
  end
  return false
end

function methods:remove_prerequisite(name)
  local filtered = {}
  for _, prerequisite in pairs(self._prototype.prerequisites or {}) do
    if prerequisite ~= name then filtered[#filtered + 1] = prerequisite end
  end
  self._prototype.prerequisites = filtered
  return self
end

function methods:add_effect(effect, identity)
  self._prototype.effects = self._prototype.effects or {}
  local key = identity or function(candidate)
    return candidate.type == effect.type
      and candidate.recipe == effect.recipe
      and candidate.modifier == effect.modifier
  end
  for _, candidate in pairs(self._prototype.effects) do
    if key(candidate) then return self end
  end
  self._prototype.effects[#self._prototype.effects + 1] = Core.deepcopy(effect)
  return self
end

function methods:unlock(recipe_name)
  return self:add_effect({ type = "unlock-recipe", recipe = recipe_name })
end

function methods:has_unlock(recipe_name)
  for _, effect in pairs(self._prototype.effects or {}) do
    if effect.type == "unlock-recipe" and effect.recipe == recipe_name then return true end
  end
  return false
end

function methods:remove_unlock(recipe_name)
  local filtered = {}
  for _, effect in pairs(self._prototype.effects or {}) do
    if not (effect.type == "unlock-recipe" and effect.recipe == recipe_name) then
      filtered[#filtered + 1] = effect
    end
  end
  self._prototype.effects = filtered
  return self
end

function methods:set_infinite(max_level)
  self._prototype.max_level = max_level or "infinite"
  return self
end

methods.setCost = methods.set_cost
methods.setCostFormula = methods.set_cost_formula
methods.setTime = methods.set_time
methods.setColors = methods.set_colors
methods.setEffects = methods.set_effects
methods.setPrerequisites = methods.set_prerequisites
methods.setInfinite = methods.set_infinite
methods.setIcon = function(self, path, size) return self:set_icon(path, size) end

return Technology
