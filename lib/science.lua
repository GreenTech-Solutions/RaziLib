local Collections = require("__razi_lib__/lib/collections")
local Prototype = require("__razi_lib__/lib/prototype")

local Science = {}

local function entry_name(entry)
  return entry and (entry.name or entry[1])
end

function Science.exists(name)
  return Prototype.exists("tool", name) or Prototype.exists("item", name)
end

function Science.add_pack(ingredients, name, amount, require_existing)
  if require_existing ~= false and not Science.exists(name) then return false end
  for _, ingredient in ipairs(ingredients or {}) do
    if entry_name(ingredient) == name then
      local current = ingredient.amount or ingredient[2] or 0
      local requested = amount or 1
      if requested > current then
        if ingredient.name then
          ingredient.amount = requested
        else
          ingredient[2] = requested
        end
      end
      return false
    end
  end
  ingredients[#ingredients + 1] = { name, amount or 1 }
  return true
end

function Science.add_existing(ingredients, names)
  for _, name in ipairs(names or {}) do Science.add_pack(ingredients, name) end
  return ingredients
end

function Science.add_first_existing(ingredients, names)
  for _, name in ipairs(names or {}) do
    if Science.exists(name) then
      Science.add_pack(ingredients, name)
      return name
    end
  end
  return nil
end

function Science.collect_from_technologies()
  local names = {}
  for _, technology in pairs(data.raw.technology or {}) do
    for _, ingredient in ipairs(technology.unit and technology.unit.ingredients or {}) do
      local name = entry_name(ingredient)
      if name and Science.exists(name) then Collections.append_unique(names, name) end
    end
  end
  return names
end

function Science.collect_from_recipes(recipe_names)
  local names = {}
  for _, recipe_name in ipairs(recipe_names or {}) do
    local recipe = Prototype.raw("recipe", recipe_name)
    for _, ingredient in ipairs(recipe and recipe.ingredients or {}) do
      local name = entry_name(ingredient)
      if name and Science.exists(name) then Collections.append_unique(names, name) end
    end
  end
  return names
end

function Science.build_ingredients(options)
  options = options or {}
  local ingredients = {}
  Science.add_existing(ingredients, options.primary_science_packs)
  Science.add_first_existing(ingredients, options.first_available_science_packs)
  Science.add_existing(ingredients, options.extra_science_packs)
  if #ingredients == 0 then
    for _, name in ipairs(options.fallback_science_packs or {}) do
      Science.add_pack(ingredients, name, 1, false)
    end
  end
  return ingredients
end

function Science.lab_has_input(lab, name)
  return lab ~= nil and name ~= nil and Collections.contains(lab.inputs or {}, name)
end

function Science.add_lab_input(lab, name, require_existing)
  if not (lab and lab.inputs and name) then return false end
  if require_existing ~= false and not Science.exists(name) then return false end
  if Science.lab_has_input(lab, name) then return false end
  lab.inputs[#lab.inputs + 1] = name
  return true
end

return Science
