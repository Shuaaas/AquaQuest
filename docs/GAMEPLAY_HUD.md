# Gameplay HUD — 1 November 2026

## Reference and final layout

The user-provided screenshot is a layout reference, not a source image used in the game. AquaQuest retains its existing brown/cream/gold/moss palette, shared theme, nearest-neighbor textures and bundled font.

- Upper left: an equipment medallion, the equipped item's name, and the actual spendable points balance. No player portrait, level, EXP amount, EXP cap or invented progress bar is shown.
- Below it: the current active quest title and objective counts. Main quests take priority over mini quests; remaining ties use stable quest-ID order. The panel scrolls when authored text is long. Its arrow opens the existing quest/performance board.
- Upper right: the existing circular live minimap, a new expand button opening the existing world map, and the actual region name.
- Right side: round Codex, Inventory and Quests shortcuts with original code-native icons. The equipment medallion also opens inventory.
- Narrow displays reduce the minimap diameter and equipment text size. Short landscape screens move shortcuts to a horizontal row at bottom right. The HUD hides while dialogue, fishing, loading, pause or gameplay overlays are active.

There is no game-day clock or functional Settings screen in the inspected project. Those example elements are omitted rather than given fabricated values or inactive buttons. The Quests shortcut uses the existing board, which already contains a Quest Journal section and performance information; no separate quest manager or settings system was created.

## Data ownership

`HUDStatus.gd` is a read-only adapter. It queries MapManager for the live local player, the player's existing FishingRodComponent for equipped state, ItemDatabase for the icon/name, FishingManager for points, RegionManager for the region name and the existing quest managers for objectives and progress.

Ownership alone does not put an item in the equipment badge. The rod must actually be equipped; unequipping shows an Empty badge and "No equipment". Cosmetic hats do not replace the equipped hand tool. After loads or player replacement, the HUD re-reads the live player rather than retaining an old Player reference.

Points mean the existing spendable balance, including shop spending. Lifetime earned points, performance scoring, prices and DDA rules are unchanged. No points are awarded by the HUD.

The only quest-manager addition is `get_objective_target_count(objective)`, a read-only public wrapper around the existing `_resolve_required_count()` function. The HUD therefore displays the same DDA-adjusted catch target used for quest completion. It does not duplicate or change that formula, complete quests, select new educational objectives or grant rewards. When the existing objectives-complete flag is set, the text asks the player to return to the quest giver.

## Shortcuts and pause handling

Codex and inventory retain their existing guarded open/close methods. The world-map expand button emits the existing open request. Quests opens the existing performance board, pauses gameplay and scrolls toward its quest section. Closing the board, Escape or P releases only the pause acquired by that HUD entry. P now uses this same guarded path. The HUD refuses to open the board over another system's pause, and removing the HUD releases its own pause.

The persistent HUD is not registered as a blocking gameplay overlay, so it does not block its own minimap or shortcuts. The full-screen root ignores mouse input; buttons and the quest scroll area handle their own input. Existing item acquisition cards and generic educational notifications retain their own behavior.

## Files created and modified

| File | Responsibility |
| --- | --- |
| `Scene/UI/GameplayHUD.tscn` | New reusable HUD root and shared skin |
| `Scripts/UI/GameplayHUD.gd` | Layout, display refresh, shortcuts and board pause ownership |
| `Scripts/UI/HUDStatus.gd` | Read-only live status and quest presentation data |
| `Scripts/UI/HUDEquipmentFrame.gd` | Original equipment medallion and name/points plates |
| `Assets/UI/HUD/codex.svg` | Original book icon |
| `Assets/UI/HUD/inventory.svg` | Original bag icon |
| `Assets/UI/HUD/quests.svg` | Original quest-scroll icon |
| `Assets/UI/HUD/expand.svg` | Original world-map expand icon |
| `Scene/Regions/main.tscn` | One persistent GameplayHUD instance |
| `Scripts/Managers/main.gd` | P delegates to the guarded HUD board shortcut |
| `Scene/UI/MiniMapUI.tscn` | Allows the existing map surface to shrink with the compact HUD |
| `Autoload/QuestObjectiveManager.gd` | Read-only target-count wrapper |
| `test/unit/test_gameplay_hud.gd` | Six integration tests |
| `docs/GAMEPLAY_HUD.md` | This report |

Godot generates import/UID metadata for new assets/scripts. Source environment artwork, other regions, movement, dialogue, fishing rules, item data, saves, DDA formulas and project settings were not changed. No external asset, font, plugin or dependency was installed. Existing work and Git changes were preserved; nothing was committed or pushed.

## Validation

Godot 4.5.1: **98 tests passed with 2,385 assertions**. Six new tests cover spendable points, ownership versus equipped state, DDA-aware objective text, return-to-NPC status, existing screen shortcuts, closing the board with P, foreign-pause preservation and layout bounds/non-overlap. The new scripts/tests pass GDScript Toolkit linting, and the diff passes whitespace checks.

Production Main rendered empty and equipped/active-quest HUD states at 1200×760, 390×844 and 720×360. Phone review corrected an overlapping region badge, initial container sizing and a clipped Inventory label. The circular terrain and marker projection still use the existing minimap system. Compatibility rendering was selected only for screenshot verification; the project's renderer setting was not changed. Screenshot points/quest/equipment values were set only in that temporary process and were not saved to player progress.

Remaining manual checks: play through accepting/turning in a quest, equipment changes, a shop purchase, save/reload and a region transition with the HUD visible. Check touch targets, physical font size and safe areas on an Android device. These engine checks are not a physical Android test or a complete manual playthrough.
