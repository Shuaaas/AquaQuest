# Item acquisition notifications

The user-provided toast image is a visual reference for a top-center item badge, framed card, stars, item name and description. The new frame is original Control drawing code; the reference image is not copied into the project. Existing item icons are reused.

## Rarity and palette

| Item rarity | Filled stars / four total slots |
| --- | --- |
| Common | 1 |
| Advanced | 2 |
| Rare | 3 |
| Epic | 4 |

Every tier uses the existing palette: ink `#160f09`, shadow `#2f1c10`, panel `#341f12`, wood `#7d4c28`, highlight gold `#ba9e6e`, cream `#ddccb8` and moss `#62791e`. Tier names and star counts carry the distinction; unrelated rarity colors are not introduced. The image reference has five star slots, but this implementation uses the four slots requested for AquaQuest.

The user approved leaving unconfigured items at Common. No existing item-to-tier mapping was invented or written to the item JSON. Optional future metadata in an item definition is `"rarity": "advanced"`, `"rare"` or `"epic"`; `"common"` is also accepted. Missing, invalid or unsupported values fall back to Common. Capitalization is normalized. ItemDatabase owns this metadata lookup. Item rarity has no relationship to DDA difficulty tiers and changes no effects, catch probabilities, rewards, prices or scoring.

## Behavior

- The persistent card listens to the existing `EventBus.item_added(item_id, amount)` signal. Actual successful grants from fishing, shops, dialogue and quests share that signal; those systems were not rewritten.
- The card shows the existing icon, name and description plus the actual quantity granted. Unknown items use readable fallback text and a question-mark badge rather than loading an empty icon path.
- Item grants queue instead of replacing each other. Consecutive pending grants of the same item merge their quantities. Each card auto-dismisses after four seconds and also has a touch-size Dismiss button.
- Cards wait during dialogue, fishing, gameplay overlays, pause, loading or an existing generic toast. An already visible card hides and its timer pauses until it is safe to resume. Generic educational, purchase and error messages retain their original text/timing/behavior.
- Cards do not pause gameplay or capture keyboard input. The fullscreen notification root ignores mouse input; the dismiss button and text scrolling are interactive.
- Full stacks emit no new item grant and therefore show no card. Restoring inventory does not emit `item_added`. Successful save loading clears stale cards; a mere load request does not discard them.
- The layout supports the tested desktop, portrait-phone and short landscape viewports. Long names/descriptions can scroll inside the card.

## Files

| File | Change |
| --- | --- |
| `Autoload/ItemDatabase.gd` | Added rarity names, validation and star lookup |
| `Scripts/UI/ItemRewardFrame.gd` | Original palette-consistent frame, badge, accents and stars |
| `Scripts/UI/ItemRewardToast.gd` | Acquisition queue, presentation, timing, layout and suppression |
| `Scene/UI/ItemRewardToast.tscn` | Reusable card scene with text, icon, timer and Dismiss button |
| `Scene/Regions/main.tscn` | One persistent item notification instance in the existing CanvasLayer |
| `test/unit/test_item_reward_toast.gd` | Eight regression tests |
| `docs/ITEM_REWARD_NOTIFICATIONS.md` | This guide |

Godot may generate script UID metadata. InventoryManager, ShopManager, FishingManager, quest logic, the existing generic ToastUI, DDA, saves, item JSON, source artwork and project settings are unchanged. No plugin, font, download or other dependency was introduced.

## Validation

Godot 4.5.1: all **92 tests passed with 2,332 assertions**. The eight new tests cover the four tiers, invalid/default metadata, real grant quantities, queueing/merging, generic-toast and pause suppression, full stacks, inventory restore, successful-load cleanup, unknown items and timer advancement. The new scripts/tests pass GDScript Toolkit linting.

The production Main scene rendered all four tiers at 1200×760, 390×844 and 720×360 without script/render errors. These screenshots temporarily assign example tiers in process memory to demonstrate the design; they do not assign those tiers to actual project items. Compatibility rendering was selected only for the screenshot process.

Manual follow-up: receive the rod through Teacher Ana, purchase an item, finish a fishing attempt, and confirm the acquisition card appears after the existing dialogue/result messages. Repeat on a physical Android device to check touch, physical readability and scrolling. A full manual acquisition playthrough and Android device test have not been claimed.


## Compact wood-and-parchment redesign
The card reuses the existing HUDReference wood/button/parchment textures and bundled smooth font. Native controls in ItemRewardToast.tscn expose the heading, name/quantity row, rarity label, parchment description, text scrolling and Dismiss button for editing. ItemRewardFrame.gd now draws only the smooth circular icon medallion. One to four filled stars appear beside the actual rarity name; no empty stars imply an upgrade rating. Existing item icons remain unchanged; the generated concept fish illustration is not installed artwork. The card stays bottom-centred and the queue, pauses, actual grant amounts, generic-toast priority and four-second duration are unchanged.
