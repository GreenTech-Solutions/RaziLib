# RAZI Library API

All imports use the stable `__razi_lib__/...` path.

## Data-stage modules

### `lib/core`

Assertions, deep copy, clamp, recursive merge, sorted keys, and stage detection.

### `lib/collections`

`contains`, `append_unique`, `unique` (stable array deduplication), `remove`, `index_by`, `map`, and `copy`.

### `lib/prototype`

- `exists(type, name)`, `raw(type, name)`
- `get(type, name)`, `optional(type, name)`
- `clone(type, from, into)`, `each(type, callback)`
- Wrapper methods: `raw`, `clone`, `set`, `set_icon`, `set_icons`, `hide`, `remove`

Wrappers proxy ordinary prototype fields, so `Recipe.get("x").ingredients` works.

### `lib/technology_graph` (new in 1.2.0)

- `reaches(technologies, from, ancestor)`: iterative, cycle-safe traversal
- `find_cycle(technologies)`: deterministic cycle witness without recursion
- `add_prerequisite(technologies, technology, prerequisite)`: idempotent,
  cycle-proof insertion; requires both prototypes to exist
- `unlock_index(technologies)`, `first_unlock(technologies, recipe, visible_only)`:
  sorted source-recipe unlocking lookup
- No global caches, implicit graph mutation or source-mod policy: consumers
  decide which nodes/edges they own and whether disabled techs are eligible.

### `lib/recipe`

- `get`, `optional`, `exists`, `clone`, `produces` (read-only, supports recipe variants)
- `set_ingredients`, `set_results`, `add_ingredient`, `upsert_ingredient`
- `has_ingredient`, `remove_ingredient`, `replace_ingredient`, `add_result`, `remove_result`
- `set_energy`, `set_categories`, `set_category`, `add_category`, `set_subgroup`, `set_modules`
- `enable`, `disable`, `set_conditions`, `set_recycling`, `set_main_product`
- `set_quality_selectable`, `set_ingredient_sorting`
- `unlock_with`, `remove_unlocks`, `each_variant`
- 2.1 migration helpers: `categories_of`, `primary_category`, `normalize_2_1`, `normalize_all_2_1`

Ingredient and category setters apply to normal and expensive variants when they exist. Product normalization migrates legacy probability and freshness fields to Factorio 2.1's product-level representation.

### `lib/technology`

- `get`, `optional`, `exists`, `first_existing`, `first_existing_name`, `clone`, `register_science`
- `has_dependents`, `set_cost`, `set_cost_formula`, `set_time`, `set_packs`, `set_colors`, `add_pack`, `has_pack`
- `set_effects`, `add_effect`, `unlock`, `has_unlock`, `remove_unlock`
- `set_prerequisites`, `add_prerequisite`, `has_prerequisite`, `remove_prerequisite`, `set_infinite`

Built-in science codes: `R G B M P Y W V F A C S`.

### `lib/science`

Science-pack discovery and composition with `exists`, `add_pack`, `add_existing`,
`add_first_existing`, `collect_from_technologies`, `collect_from_recipes`,
`build_ingredients`, `lab_has_input`, and `add_lab_input`.

### `lib/space_connection`

Optional Space Age route editing with `remove`, `remove_between`, `remove_all`,
and `remove_except_locations`. The module remains passive and does not add a
Space Age dependency.

### `lib/item`, `lib/entity`, `lib/module`

Typed convenience wrappers for common stack, placement, crafting, energy, module,
surface-condition, effect, category, and tier changes. The item and module helpers
also expose Factorio 2.1 spoil-quality policies and per-effect quality multipliers.

### `lib/icons`

Build deterministic layered icons with `layer`, `single`, `compose`, `badge`,
`from_prototype`, and `tint`.

### `lib/settings`

Read settings safely with `value` and `enabled`. Build prototypes with `bool`,
`string`, `int`, and `double`.

### `lib/locale`

Construct localized keys, concatenations, rich-text icons, and colored values.

### `lib/validation`

Assertions for prototypes, recipe ingredients/results, technology unlocks and
prerequisites, plus duplicate-name detection. Intended for `data-final-fixes`.

## Runtime modules

### `runtime/events`

Creates a consumer-owned registry supporting multiple handlers for events,
nth-tick callbacks, init, load, configuration changes, and module inclusion.

### `runtime/storage`

Namespaced persistent state with defaults: `ensure`, `get`, `set`, `update`,
and `reset`.

### `runtime/remote`

Safe `has`, optional `call`, strict `require`, and idempotent `add_interface`.

## Migration from `haul_lib`

| Old | RAZI Library |
|---|---|
| `__haul_lib__/utils/common` | `__razi_lib__/lib/prototype` or compatibility `utils/common` |
| `__haul_lib__/utils/recipe` | `__razi_lib__/lib/recipe` |
| `__haul_lib__/utils/tech` | `__razi_lib__/lib/technology` |
| `__haul_lib__/utils/module` | `__razi_lib__/lib/module` |

CamelCase aliases remain for the small legacy surface, but new projects should
use snake_case names.
