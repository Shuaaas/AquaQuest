# Wooden inventory design

The approved mockup is implemented as editable native Godot controls in
`Scene/UI/inventory_ui.tscn`. The wooden palette, gold frames, cream text and blue
selection accent reuse existing HUDReference SVGs. The shared PixelUIStyle font
is copied into this inventory's local theme so other menus remain unchanged.
The generated concept image is not pasted over the interface. Its illustrated rod,
lantern and detailed grain were not substituted for existing game artwork: actual
item icons and existing frame textures remain the assets used by the game.

## Layout and editing

Open the inventory scene in Godot's 2D workspace. Expand Margin > Panel > Layout:
- Header: title, Codex and Close buttons.
- FilterScroll > FilterContainer: horizontally scrollable categories; buttons are
  populated from the existing category list by inventory_ui.gd.
- InfoRow: actual owned item-type count and sorting.
- BodyScroll > Body: responsive BoxContainer containing GridPanel and DetailsPanel.
- GridPanel > GridLayout > GridScroll > ItemListContainer: selectable 3-column grid.
- DetailsPanel > DetailsLayout: selected item's preview, name, category, rarity,
  description, quantity/stack limit, status and action button.

Static controls, textures, styleboxes, margins and container separation are editable
in the scene. Live labels, icons, selection and slot buttons are populated from game
data. Keep unique node names intact. GridPanel and DetailsPanel minimum heights and
slot heights are managed by the responsive layout. Below 700 pixels wide the panels
stack; the outer scroll reaches the details/action panel. Category tabs scroll
horizontally when necessary. Short landscape screens retain a compact item title
and a visible action button while item details scroll inside their panel.

## Preserved rules and truthful data

The item count represents distinct owned item IDs. There is no 30-slot capacity in
the current managers, and this UI does not create one. Twelve initial grid cells are
visual placeholders; inventories larger than twelve display all their items and
scroll. Quantities and per-item stack limits come from existing managers.

Selected items show ItemDatabase rarity and 1–4 stars, with the existing Common
default for unconfigured items. Unknown item icons use the item's name instead of a
fictional picture. No item data, rarity mapping, shop prices or educational text
was changed.

Rod Equip/Unequip still calls FishingRodComponent.toggle(). Hat actions still call
InventoryManager.toggle_costume(). Bait retains its no-effect warning, cannot be
used and is not consumed. Materials/quest items expose no invented action. Selecting,
filtering or sorting does not alter item counts or points. Inventory changes refresh
the selection, and removed items cannot leave an active stale action. Keyboard focus
survives sorting. Codex handoff, Escape/I closing and pause ownership are preserved.

## Changed files
- Scene/UI/inventory_ui.tscn: editable wooden grid/details scene and local theme.
- Scripts/Systems/Inventory/inventory_ui.gd: selection and responsive presentation;
  existing manager calls retained.
- test/unit/test_inventory_shop.gd: adapted list assertions and five new checks for
  selection/actions, placeholders/bait, responsive reachability, count/point safety
  and keyboard/Codex handoff.
- docs/INVENTORY_DESIGN.md: this guide.

No managers, shops, gameplay scenes, saves, scoring/DDA rules, project settings,
AGENTS.md, dependencies or existing asset files were modified by this task.

## Validation

Godot 4.5.1: all 18 inventory/shop tests pass. Full GUT suite: 127/130 pass, with the
same three pre-existing Region 1 layout failures at test/unit/test_region1_layout.gd
lines 106, 170 and 189–190. Existing HUD/Performance Board tests also pass in that run.

Tests cover actual rod/hat actions, unusable bait, empty and filtered states,
selection removal, more than twelve item types, unchanged counts/points, sorting,
focus, pause-safe close, Codex handoff, and viewport/action reachability at 390x844,
600x900, 856x428 and 1280x720. Native renders were inspected at those sizes and at the
portrait scrolled detail view. Preview captures use temporary test items; they do
not grant items or write player saves. The main editor loaded the real scene; live
open/close left items and points unchanged and released pause.

Actual Android device testing, notch safe areas, touch scroll comfort and very large
text/accessibility settings still require manual validation. Existing pixel icons
are visibly simpler than the concept illustration; no replacement art is required
for functionality, but bespoke detailed icons would be a separate art task.
