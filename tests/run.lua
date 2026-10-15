local native_require = require

function require(name)
  return native_require((name:gsub("^__razi_lib__/", "")))
end

table.deepcopy = function(value)
  if type(value) ~= "table" then return value end
  local copy = {}
  for key, entry in pairs(value) do copy[table.deepcopy(key)] = table.deepcopy(entry) end
  return copy
end

data = {
  raw = {
    recipe = {
      alpha = { type = "recipe", name = "alpha", ingredients = { { "iron-plate", 1 } }, result = "gear" },
      beta = { type = "recipe", name = "beta", ingredients = {}, results = {} },
    },
    technology = {
      automation = { type = "technology", name = "automation", unit = { count = 10, ingredients = {}, time = 30 } },
      logistics = { type = "technology", name = "logistics", unit = { count = 20, ingredients = {}, time = 30 } },
    },
    item = {
      gear = { type = "item", name = "gear", stack_size = 100 },
      plate = { type = "item", name = "plate", stack_size = 100 },
    },
    tool = {
      ["automation-science-pack"] = { type = "tool", name = "automation-science-pack" },
      ["logistic-science-pack"] = { type = "tool", name = "logistic-science-pack" },
    },
    ["space-connection"] = {
      ["nauvis-vulcanus"] = { type = "space-connection", name = "nauvis-vulcanus", from = "nauvis", to = "vulcanus" },
      ["vulcanus-fulgora"] = { type = "space-connection", name = "vulcanus-fulgora", from = "vulcanus", to = "fulgora" },
    },
  },
}

local passed = 0
local function test(name, callback)
  local ok, message = pcall(callback)
  if not ok then error(("FAIL %s: %s"):format(name, message), 0) end
  passed = passed + 1
end

local Recipe = require("__razi_lib__/lib/recipe")
local Technology = require("__razi_lib__/lib/technology")
local Prototype = require("__razi_lib__/lib/prototype")
local Science = require("__razi_lib__/lib/science")
local SpaceConnection = require("__razi_lib__/lib/space_connection")
local Graph = require("__razi_lib__/lib/technology_graph")
local Collections = require("__razi_lib__/lib/collections")

test("wrappers retain independent targets", function()
  local alpha = Recipe.get("alpha")
  local beta = Recipe.get("beta")
  alpha:set_energy(2)
  beta:set_energy(7)
  assert(data.raw.recipe.alpha.energy_required == 2)
  assert(data.raw.recipe.beta.energy_required == 7)
end)

test("recipe edits normalize legacy results", function()
  Recipe.get("alpha")
    :upsert_ingredient({ name = "copper-plate", amount = 2 })
    :add_result("plate", 3)
  assert(data.raw.recipe.alpha.result == nil)
  assert(data.raw.recipe.alpha.results[1].name == "gear")
  assert(data.raw.recipe.alpha.results[2].name == "plate")
end)

test("Factorio 2.1 recipe normalization is lossless", function()
  data.raw.recipe.beta.category = "chemistry"
  data.raw.recipe.beta.additional_categories = { "cryogenics" }
  data.raw.recipe.beta.results = {
    { type = "item", name = "plate", amount = 1, probability = 0.25 },
  }
  Recipe.normalize_2_1(data.raw.recipe.beta)
  assert(data.raw.recipe.beta.category == nil)
  assert(data.raw.recipe.beta.categories[1] == "chemistry")
  assert(data.raw.recipe.beta.categories[2] == "cryogenics")
  assert(data.raw.recipe.beta.results[1].probability == nil)
  assert(data.raw.recipe.beta.results[1].independent_probability == 0.25)
end)

test("technology edits are idempotent", function()
  Technology.get("automation")
    :add_prerequisite("logistics")
    :add_prerequisite("logistics")
    :unlock("alpha")
    :unlock("alpha")
    :set_colors("RGB")
  assert(#data.raw.technology.automation.prerequisites == 1)
  assert(#data.raw.technology.automation.effects == 1)
  assert(#data.raw.technology.automation.unit.ingredients == 3)
  assert(Technology.get("automation"):has_prerequisite("logistics"))
  assert(Technology.get("automation"):has_unlock("alpha"))
  assert(Technology.get("automation"):has_pack("chemical-science-pack"))
  assert(Technology.first_existing_name({ "missing", "automation" }) == "automation")
  assert(Technology.has_dependents("logistics"))
end)

test("recipe inspection covers variants", function()
  data.raw.recipe.beta.normal = { ingredients = { { "plate", 2 } } }
  assert(Recipe.exists("beta"))
  assert(Recipe.get("beta"):has_ingredient("plate"))
end)

test("science helpers compose available packs and labs", function()
  local ingredients = Science.build_ingredients({
    primary_science_packs = { "automation-science-pack", "missing-pack" },
    first_available_science_packs = { "missing-pack", "logistic-science-pack" },
  })
  assert(#ingredients == 2)
  assert(Science.add_pack(ingredients, "automation-science-pack") == false)
  local lab = { inputs = { "automation-science-pack" } }
  assert(Science.add_lab_input(lab, "logistic-science-pack"))
  assert(Science.lab_has_input(lab, "logistic-science-pack"))
end)

test("space connection helpers remove only selected routes", function()
  SpaceConnection.remove_between("vulcanus", "nauvis")
  assert(data.raw["space-connection"]["nauvis-vulcanus"] == nil)
  assert(data.raw["space-connection"]["vulcanus-fulgora"] ~= nil)
  SpaceConnection.remove_except_locations({ "nauvis" })
  assert(next(data.raw["space-connection"]) == nil)
end)

test("generic clones and wrappers remain typed", function()
  local clone = Recipe.get("beta"):clone("gamma"):set_energy(4)
  assert(clone.name == "gamma")
  assert(data.raw.recipe.gamma.energy_required == 4)
  Prototype.get("item", "gear"):clone("gear-copy"):set({ stack_size = 20 })
  assert(data.raw.item["gear-copy"].stack_size == 20)
end)

test("settings helpers preserve false and zero", function()
  settings = { startup = { enabled = { value = false }, count = { value = 0 } } }
  local Settings = require("__razi_lib__/lib/settings")
  assert(Settings.value("enabled", true) == false)
  assert(Settings.value("count", 9) == 0)
end)

test("event registry composes multiple consumers", function()
  local calls = {}
  local script_api = {}
  function script_api.on_event(id, handler) calls.event_id, calls.event = id, handler end
  function script_api.on_nth_tick(id, handler) calls.nth_id, calls.nth = id, handler end
  function script_api.on_init(handler) calls.init = handler end
  function script_api.on_load(handler) calls.load = handler end
  function script_api.on_configuration_changed(handler) calls.changed = handler end
  local Events = require("__razi_lib__/runtime/events")
  local registry = Events.new()
  local total = 0
  registry:on_event(5, function() total = total + 1 end)
  registry:on_event(5, function() total = total + 2 end)
  registry:on_init(function() total = total + 4 end):install(script_api)
  calls.event({})
  calls.init()
  assert(total == 7)
end)

test("storage namespaces isolate defaults", function()
  storage = {}
  local Storage = require("__razi_lib__/runtime/storage")
  local state = Storage.namespace("example", { count = 1 })
  assert(state:update("count", function(value) return value + 2 end) == 3)
  assert(storage.example.count == 3)
end)


test("ordered collection unique preserves first occurrence", function()
  local unique = Collections.unique({"one", "two", "one", "three", "two"})
  assert(table.concat(unique, ",") == "one,two,three")
  local entries = Collections.unique({{name="A",v=1},{name="A",v=2},{name="B",v=3}}, "name")
  assert(#entries == 2 and entries[1].v == 1 and entries[2].name == "B")
end)

test("recipe read-only product inspection includes variants", function()
  assert(Recipe.produces("alpha", "gear"))
  assert(Recipe.produces(data.raw.recipe.beta, "plate") == false)
  assert(Recipe.produces({normal={results={{"rare-item",2}}}}, "rare-item"))
  assert(not Recipe.produces(nil, "rare-item"))
end)

test("iterative technology ancestry tolerates missing nodes and cycles", function()
  local graph = {
    a={prerequisites={"b","missing"}},
    b={prerequisites={"c"}},
    c={prerequisites={"a"}},
    other={prerequisites={}}
  }
  assert(Graph.reaches(graph,"a","c"))
  assert(not Graph.reaches(graph,"a","other"))
  assert(Graph.reaches(graph,"missing","missing"))
  assert(table.concat(Graph.find_cycle(graph), ",") == "a,b,c")
  assert(not Graph.add_prerequisite(graph,"b","a"))
  assert(Graph.add_prerequisite(graph,"other","a"))
  assert(not Graph.add_prerequisite(graph,"a","other"))
end)

test("safe prerequisite insertion and unlock lookup stay idempotent", function()
  local graph = {
    a={prerequisites={}},
    b={prerequisites={"a"},effects={{type="unlock-recipe",recipe="gear"},
      {type="unlock-recipe",recipe="gear"}}},
    c={prerequisites={},effects={{type="unlock-recipe",recipe="gear"}}},
    disabled={enabled=false,effects={{type="unlock-recipe",recipe="gear"}}}
  }
  assert(not Graph.add_prerequisite(graph,"a","b"))
  assert(not Graph.add_prerequisite(graph,"b","a"))
  assert(Graph.add_prerequisite(graph,"c","b"))
  assert(not Graph.add_prerequisite(graph,"c","a"))
  assert(not Graph.add_prerequisite(graph,"c","b"))
  assert(#graph.c.prerequisites == 1)
  local index=Graph.unlock_index(graph)
  assert(table.concat(index.gear,",")=="b,c,disabled")
  assert(Graph.first_unlock(graph,"gear",true)=="b")
  graph.b.hidden=true
  assert(Graph.first_unlock(graph,"gear",true)=="c")
end)

test("deep technology chain avoids recursive stack overflow", function()
  local graph={}
  for i=1,4000 do
    graph["chain-"..i]={prerequisites=i>1 and {"chain-"..(i-1)} or {}}
  end
  assert(Graph.reaches(graph,"chain-4000","chain-1"))
  assert(Graph.find_cycle(graph)==nil)
  graph["chain-1"].prerequisites={"chain-4000"}
  assert(Graph.find_cycle(graph)~=nil)
end)

io.write(("RAZI Library: %d tests passed\n"):format(passed))
