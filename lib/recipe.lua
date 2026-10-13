local Core = require("__razi_lib__/lib/core")
local Prototype = require("__razi_lib__/lib/prototype")

local Recipe = {}
local methods = {}

local function requested_name(self_or_name, maybe_name)
  return maybe_name or self_or_name
end

local function entry_name(entry)
  return entry and (entry.name or entry[1])
end

local function normalized_entry(spec, default_type)
  if type(spec) == "string" then return { type = default_type or "item", name = spec, amount = 1 } end
  if spec.name or spec.type then return Core.deepcopy(spec) end
  return { type = default_type or "item", name = spec[1], amount = spec[2] or 1 }
end

local function variants(recipe)
  local found = { recipe }
  if recipe.normal then found[#found + 1] = recipe.normal end
  if recipe.expensive then found[#found + 1] = recipe.expensive end
  return found
end

local function category_list(value)
  if type(value) == "string" then return { value } end
  return Core.deepcopy(value or { "crafting" })
end

local function append_unique(list, value)
  for _, current in ipairs(list) do
    if current == value then return end
  end
  list[#list + 1] = value
end

local function normalize_product_list(results, freshness_source)
  for _, result in pairs(results or {}) do
    if result.probability ~= nil and result.independent_probability == nil then
      result.independent_probability = result.probability
    end
    result.probability = nil
    if freshness_source and freshness_source.result_is_always_fresh ~= nil and result.always_fresh == nil then
      result.always_fresh = freshness_source.result_is_always_fresh
    end
    if freshness_source and freshness_source.reset_freshness_on_craft ~= nil and result.reset_freshness_on_craft == nil then
      result.reset_freshness_on_craft = freshness_source.reset_freshness_on_craft
    end
  end
  return results
end

local function normalize_products(recipe)
  for _, variant in ipairs(variants(recipe)) do
    normalize_product_list(variant.results, variant)
    variant.result_is_always_fresh = nil
    variant.reset_freshness_on_craft = nil
  end
end

local function apply_variants(self, callback)
  for _, variant in ipairs(variants(self._prototype)) do callback(variant) end
  return self
end

local function normalize_legacy_result(variant)
  if variant.result then
    variant.results = variant.results or {
      { type = "item", name = variant.result, amount = variant.result_count or 1 },
    }
    variant.result = nil
    variant.result_count = nil
  end
  variant.results = variant.results or {}
end

function Recipe.get(self_or_name, maybe_name)
  return Prototype.get("recipe", requested_name(self_or_name, maybe_name), methods)
end

function Recipe.optional(self_or_name, maybe_name)
  return Prototype.optional("recipe", requested_name(self_or_name, maybe_name), methods)
end

function Recipe.exists(self_or_name, maybe_name)
  return Prototype.exists("recipe", requested_name(self_or_name, maybe_name))
end

function Recipe.clone(self_or_from, from_or_into, maybe_into)
  local from = maybe_into and from_or_into or self_or_from
  local into = maybe_into or from_or_into
  Prototype.clone("recipe", from, into)
  return Recipe.get(into)
end

function Recipe.categories_of(recipe)
  local categories = category_list(recipe.categories or recipe.category)
  for _, category in ipairs(recipe.additional_categories or {}) do append_unique(categories, category) end
  return categories
end

function Recipe.primary_category(recipe)
  return Recipe.categories_of(recipe)[1] or "crafting"
end

function Recipe.normalize_2_1(recipe)
  recipe.categories = Recipe.categories_of(recipe)
  recipe.category = nil
  recipe.additional_categories = nil
  normalize_products(recipe)
  return recipe
end

function Recipe.normalize_product_list_2_1(results)
  return normalize_product_list(results)
end

function Recipe.normalize_all_2_1()
  for _, recipe in pairs(data.raw.recipe or {}) do Recipe.normalize_2_1(recipe) end
  for _, prototypes in pairs(data.raw or {}) do
    for _, prototype in pairs(prototypes) do
      if prototype.minable then normalize_product_list(prototype.minable.results) end
      normalize_product_list(prototype.loot)
    end
  end
  return Recipe
end

Recipe.cloneInto = Recipe.clone

function methods:each_variant(callback)
  apply_variants(self, callback)
  return self
end

function methods:set_ingredients(ingredients)
  return apply_variants(self, function(variant) variant.ingredients = Core.deepcopy(ingredients) end)
end

function methods:set_results(results)
  return apply_variants(self, function(variant)
    variant.result = nil
    variant.result_count = nil
    variant.results = Core.deepcopy(results)
  end)
end

function methods:add_ingredient(spec, amount, ingredient_type)
  local addition = type(spec) == "string"
    and { type = ingredient_type or "item", name = spec, amount = amount or 1 }
    or normalized_entry(spec, "item")
  return apply_variants(self, function(variant)
    variant.ingredients = variant.ingredients or {}
    for _, ingredient in pairs(variant.ingredients) do
      if entry_name(ingredient) == addition.name and (ingredient.type or "item") == (addition.type or "item") then
        ingredient.amount = (ingredient.amount or ingredient[2] or 0) + (addition.amount or 1)
        ingredient[2] = nil
        return
      end
    end
    variant.ingredients[#variant.ingredients + 1] = Core.deepcopy(addition)
  end)
end

function methods:upsert_ingredient(spec, minimum_amount)
  local addition = normalized_entry(spec, "item")
  if minimum_amount then addition.amount = minimum_amount end
  return apply_variants(self, function(variant)
    variant.ingredients = variant.ingredients or {}
    for _, ingredient in pairs(variant.ingredients) do
      if entry_name(ingredient) == addition.name and (ingredient.type or "item") == (addition.type or "item") then
        ingredient.amount = math.max(ingredient.amount or ingredient[2] or 0, addition.amount or 1)
        ingredient[2] = nil
        return
      end
    end
    variant.ingredients[#variant.ingredients + 1] = Core.deepcopy(addition)
  end)
end

function methods:remove_ingredient(name, ingredient_type)
  return apply_variants(self, function(variant)
    local filtered = {}
    for _, ingredient in pairs(variant.ingredients or {}) do
      if entry_name(ingredient) ~= name
        or (ingredient_type and (ingredient.type or "item") ~= ingredient_type)
      then
        filtered[#filtered + 1] = ingredient
      end
    end
    variant.ingredients = filtered
  end)
end

function methods:has_ingredient(name, ingredient_type)
  for _, variant in ipairs(variants(self._prototype)) do
    for _, ingredient in pairs(variant.ingredients or {}) do
      if entry_name(ingredient) == name
        and (not ingredient_type or (ingredient.type or "item") == ingredient_type)
      then
        return true
      end
    end
  end
  return false
end

function methods:replace_ingredient(old_name, replacement)
  return self:remove_ingredient(old_name):upsert_ingredient(replacement)
end

function methods:add_result(spec, amount, result_type)
  local addition = type(spec) == "string"
    and { type = result_type or "item", name = spec, amount = amount or 1 }
    or normalized_entry(spec, "item")
  return apply_variants(self, function(variant)
    normalize_legacy_result(variant)
    variant.results[#variant.results + 1] = Core.deepcopy(addition)
  end)
end

function methods:remove_result(name, result_type)
  return apply_variants(self, function(variant)
    normalize_legacy_result(variant)
    local filtered = {}
    for _, result in pairs(variant.results or {}) do
      if entry_name(result) ~= name or (result_type and (result.type or "item") ~= result_type) then
        filtered[#filtered + 1] = result
      end
    end
    variant.results = filtered
  end)
end

function methods:set_energy(seconds)
  return apply_variants(self, function(variant) variant.energy_required = seconds end)
end

function methods:set_categories(categories)
  return apply_variants(self, function(variant)
    variant.categories = category_list(categories)
    variant.category = nil
    variant.additional_categories = nil
  end)
end


function methods:set_category(category) return self:set_categories(category) end

function methods:add_category(category)
  return apply_variants(self, function(variant)
    variant.categories = Recipe.categories_of(variant)
    append_unique(variant.categories, category)
    variant.category = nil
    variant.additional_categories = nil
  end)
end

function methods:set_subgroup(subgroup, order)
  self._prototype.subgroup = subgroup
  if order then self._prototype.order = order end
  return self
end

function methods:set_modules(codes)
  local allowed = type(codes) == "table" and codes or {
    consumption = codes:find("E", 1, true) ~= nil,
    speed = codes:find("S", 1, true) ~= nil,
    productivity = codes:find("P", 1, true) ~= nil,
    pollution = codes:find("D", 1, true) ~= nil,
    quality = codes:find("Q", 1, true) ~= nil,
  }
  return apply_variants(self, function(variant)
    variant.allow_consumption = allowed.consumption == true
    variant.allow_speed = allowed.speed == true
    variant.allow_productivity = allowed.productivity == true
    variant.allow_pollution = allowed.pollution == true
    variant.allow_quality = allowed.quality == true
  end)
end

function methods:enable() return apply_variants(self, function(variant) variant.enabled = true end) end
function methods:disable() return apply_variants(self, function(variant) variant.enabled = false end) end

function methods:set_conditions(conditions)
  return apply_variants(self, function(variant) variant.surface_conditions = Core.deepcopy(conditions) end)
end

function methods:set_recycling(enabled)
  self._prototype.auto_recycle = enabled
  return self
end

function methods:set_main_product(name)
  self._prototype.main_product = name
  return self
end

function methods:set_quality_selectable(enabled)
  self._prototype.can_set_quality = enabled ~= false
  return self
end

function methods:set_ingredient_sorting(enabled)
  self._prototype.sort_item_ingredients = enabled ~= false
  return self
end

function methods:unlock_with(technology_name)
  local technology = data.raw.technology and data.raw.technology[technology_name]
  assert(technology, "Technology '" .. technology_name .. "' not found")
  technology.effects = technology.effects or {}
  for _, effect in pairs(technology.effects) do
    if effect.type == "unlock-recipe" and effect.recipe == self._name then return self end
  end
  technology.effects[#technology.effects + 1] = { type = "unlock-recipe", recipe = self._name }
  self:disable()
  return self
end

function methods:remove_unlocks()
  for _, technology in pairs(data.raw.technology or {}) do
    local filtered = {}
    for _, effect in pairs(technology.effects or {}) do
      if not (effect.type == "unlock-recipe" and effect.recipe == self._name) then
        filtered[#filtered + 1] = effect
      end
    end
    technology.effects = filtered
  end
  return self
end

methods.setIngredients = methods.set_ingredients
methods.setProducts = methods.set_results
methods.setEnergy = methods.set_energy
methods.setCategory = methods.set_category
methods.setCategories = methods.set_categories
methods.setModules = methods.set_modules
methods.setConditions = methods.set_conditions
methods.setRecycle = methods.set_recycling
methods.setIcon = function(self, path, size) return self:set_icon(path, size) end

return Recipe
