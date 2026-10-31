# Inventory and shop update — 31 October 2026

## Player-facing changes

- Inventory opens through its HUD button or I, closes through Close, Escape or I, and pauses the world only for the time it owns the pause. Existing interactions prevent it from opening. Codex closes inventory before acquiring its own pause.
- Category tabs use actual item categories, show the selected tab and scroll horizontally on narrow screens. Sorting by name, category and quantity has a visible control. Empty lists explain why nothing is shown.
- Reusable item cards show original pixel icons, names, quantities, descriptions, categories and stack limits. The eight formerly missing icon references now point to original SVG assets in `Assets/UI/Items/`.
- Rod Equip/Unequip buttons call the existing player rod component. Removing the last rod unequips it. The existing keyboard rod action remains available.
- Fisher's Hat can be worn/removed. It draws an original pixel hat above the player and saves its cosmetic selection in the inventory section. It changes no score, fishing rule or DDA input.
- Shop cards show owned quantity, price, stock, requested quantity, total cost and a visible reason when purchase is unavailable. Quantity controls include large minus/plus buttons. Close and Escape release only the pause acquired by this shop.

The production store sells the existing Fishing Rod for the previous catalog price of 10 points (one in stock), plus Fisher's Hat at its authored price of 50 points (one in stock). Rod ownership is still limited to one. Teacher Ana's existing free rod grant is unchanged. The catalog no longer references the undefined `basic rod` item.

Energy Bait has no usable effect configured and is clearly labeled in inventory. It is not consumed or offered for purchase. Selling remains disabled. These two choices were explicitly confirmed by the user; no bait effects, selling rewards or DDA changes were invented.

## Data and transaction safeguards

Inventory rejects zero/negative removals and empty grants, respects stack limits and emits the actual quantity added rather than the requested overflow. Save loading normalizes numeric counts, rejects invalid values and checks cosmetic ownership. Unknown item IDs remain supported for compatibility with existing rewards.

Old saves containing `basic rod` migrate that count to `fishing_rod`, capped at one; old limited stock for that ID is mapped too. This repair does not award points. No existing save is rewritten until the player uses the normal save function.

Purchases validate the whole quantity, item definition, stock, ownership, capacity and total price before committing. A transaction guard prevents purchases triggered synchronously by signal listeners from entering another transaction. Existing FishingManager spending handles the balance; earned/performance score and DDA rules were not changed. Stock loading supplies defaults for new catalog items while retaining valid saved stock and one-time history.

## Files changed

| Files | Responsibility |
| --- | --- |
| `Autoload/InventoryManager.gd` | Counts, validation, legacy item repair, saved cosmetic selection |
| `Autoload/ShopManager.gd` | Quantity transactions, availability reasons, catalog details, stock restoration |
| `Data/JSON/Item/items.json` | Eight valid icon references |
| `Data/JSON/Shops/general_store.json` | Correct rod and existing hat catalog entries |
| `Scripts/Systems/Inventory/inventory_ui.gd` | Inventory input, filters, sorting, cards and equipment controls |
| `Scripts/Systems/Inventory/ShopUI.gd` | Detailed shop cards, quantity controls, availability and pause handling |
| `Scripts/Systems/Inventory/ItemCard.gd` | Shared item presentation |
| `Scripts/Systems/Inventory/InventoryLauncher.gd` | Touch-friendly HUD button and overlay visibility |
| `Scripts/Systems/Inventory/CostumeAppearance.gd` | Cosmetic hat drawing |
| `Scripts/Systems/Fishing/FishingRodComponent.gd` | Unequip when the last rod is removed |
| `Scripts/Managers/main.gd` | I uses the guarded inventory-opening method |
| `Scene/UI/inventory_ui.tscn` | Category scroll area, sorting and Close controls |
| `Scene/Regions/main.tscn` | Inventory HUD button |
| `Scene/Player/player.tscn` | Cosmetic appearance child |
| `Resources/UI/AquaQuestTheme.tres` | Matching quantity-field styling |
| `Assets/UI/Items/*.svg` | Eight original item icons; Godot generates import metadata |
| `test/unit/test_inventory_shop.gd` | Thirteen regression tests |

Godot may generate `.uid` files for new scripts. No dependency, autoload registration, project setting, educational content or source environment artwork was added or changed.

## Validation and remaining manual checks

Godot 4.5.1: all 77 GUT tests passed with 1,255 assertions. Thirteen new tests cover catalog references, icon availability, purchases, equipment, failure paths, bulk capacity/stock checks, one-time history, saved-data repair, filters, pause ownership, cosmetic appearance, a real isolated-slot save/load and a reentrant purchase attempt. Existing tests continue covering player save restoration and adjacent Codex/map systems. New inventory presentation scripts pass GDScript Toolkit linting.

Engine-rendered checks cover both screens at 1200×760, 390×844 and 720×360, and the hat/HUD in the production region. The Compatibility renderer was selected only for the check process; project renderer settings are unchanged. Existing warnings about future Codex regions and the production region's missing default spawn remain unrelated to this update.

Physical Android testing is still required for device DPI, the keyboard, safe areas, scrolling, and touch targets. Manually walk through merchant dialogue → purchase → inventory → equip → fishing, then save/restart/load. Test the hat while walking/running/fishing in all directions; its present overlay is static pixel artwork, not an independently animated clothing spritesheet. No sale or consumable-effect workflow is claimed.
