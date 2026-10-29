# AquaQuest Codex system — Phase 2

## Using the reader

The existing Main scene now contains one persistent Codex UI instance. Open Inventory with the existing **I** key and choose **Learning Codex**. Choose a module and lesson. Close with **Close** or the existing `ui_cancel` action (Escape on desktop).

All 24 production lessons intentionally remain locked because the user chose to leave quest mappings unconfigured. Clicking a locked row shows its title and lock explanation; it does not reveal the lesson body or grant progress. Automated tests and visual checks use temporary progress/fixtures to verify the unlocked reader without editing any production lesson requirements or saving that demonstration progress.

The reader shows unlocked lesson summaries, full sections, concepts, examples, structured table rows, supplied diagrams, captions, source page numbers and bibliography entries. It treats source text as plain text, with BBCode disabled. Missing images produce a readable placeholder; source PDFs are provenance only and are never required at runtime. No educational content or quiz questions were added.

The reader pauses gameplay through the existing GameManager pause API and continues processing its own controls. It refuses to open during an existing pause, dialogue, fishing, scene transition, or save restoration. Closing or removing the reader releases only a pause it acquired. Inventory and other persistent UI nodes remain intact behind it; repeated open requests reuse the same instance.

The interface uses the existing Control/CanvasLayer pattern. A two-column desktop/landscape layout becomes a vertical navigation-and-reader layout on narrow portrait screens. Interactive buttons are at least 48 pixels high. Small raster statistics may still need instructor-quality source assets or a later image-zoom feature; a physical Android playthrough has not been performed.

## Responsibilities and data flow

```text
Inventory button -> EventBus.codex_open_requested -> persistent CodexUI
index.json -> CodexManager -> validated module/lesson dictionaries -> CodexUI
QuestManager.complete_quest -> EventBus.quest_completed
  -> CodexManager checks real definition + completed state + configured lesson requirement
  -> codex_lesson_unlocked / codex_progress_changed -> reader refresh
SaveManager section callbacks <-> unlocked lesson IDs
load_completed -> reconcile already-completed configured quests
```

UIManager's existing screen stack has no registered root or screens in Main, so this implementation does not introduce a second opening pattern or rework that unused stack. The Inventory button follows the existing EventBus approach and the Codex is a persistent scene, like the other current UI screens.

CodexManager loads `res://Resources/Codex/index.json`, then only the module JSON paths listed there. It validates the actual schema: module identity/source page count; lesson identity, summary, sections and requirements; nested concepts/examples/images/references/tables; and source-page bounds. Missing/malformed files, invalid records, duplicate module/lesson IDs and unsupported conditions produce diagnostics. Valid modules/lessons can still load when another record fails. `get_diagnostics()` returns the messages, and the editor also receives useful warnings. Public getters return copied data to protect the static catalog from UI mutations.

Content access APIs:

- `get_modules()` returns ordered module IDs and titles.
- `get_module(module_id)`, `get_lessons(module_id)` and `get_lesson(lesson_id)` return copied catalog data.
- `is_lesson_unlocked(lesson_id)` and `get_lock_message(lesson_id)` provide presentation state.
- `load_catalog(index_path)` reloads content and validates configured quest references.

## Configuring unlocks later

No production JSON files were changed in Phase 2. After agreeing an educational mapping, set a lesson's existing `unlock_requirement.id` to an actual quest ID in `Data/JSON/Quests/`, keeping `type` as `quest`. The implementation verifies the ID through the existing QuestObjectiveManager's read-only lookup. The only current definitions are `learn_post_harvest_basics` and `visit_region2_mini`; their existence does not imply either should unlock any particular module or lesson.

An empty quest ID, unsupported condition, or unknown quest ID does not grant an unlock. Only completed quest state grants a configured unlock: starting a quest, satisfying its objectives without turn-in, or simply emitting a completion signal without completed state is insufficient. The manager does not start, complete, reward or otherwise modify quests. Previously saved valid unlocked lessons remain available for review even if a later content revision changes their requirement. Deleted/unknown saved lesson IDs are reported and discarded.

## Persistence and compatibility

Save format version stays **1**. The new optional section contains only:

```json
{"codex": {"unlocked_lesson_ids": ["module_1_lesson_1"]}}
```

This is an example of the shape inside the existing `sections` object, not a new top-level save file and not a production unlock mapping. The lesson database, images and UI state are not saved.

`SaveManager.register_section()` now accepts optional fourth argument `apply_when_missing`, defaulting to `false`. Codex opts in with `true`. When an older save has no Codex section, its callback receives `{}` and clears the previous slot's unlocked IDs. Other sections retain their prior missing-section behavior. This prevents a player from carrying unlocks from a newer save into an older one. After a successful load, Codex reconciles only configured lessons whose real quests are already completed. Malformed Codex progress is reported and rejected, rather than silently granting access.

The existing `game_started` event clears Codex progress for a new game. There is no automatic save on closing the reader; it uses the game's existing save flow (the Main script's **N** save and **M** load shortcuts after the reader is closed). New-game clearing of other systems remains their existing responsibility.

## Created and changed files

| File | Change and purpose |
| --- | --- |
| `Autoload/CodexManager.gd` | New static catalog validation, retrieval, quest unlocks, diagnostics and save callbacks. |
| `Scripts/UI/CodexUI.gd` | New reader rendering, selection, missing-image fallback, pause/input protection and responsive sizing. |
| `Scene/UI/CodexUI.tscn` | New responsive screen with module selector, lesson list, content scroll and close button. |
| `Autoload/EventBus.gd` | Three additive Codex request/progress signals. |
| `Autoload/QuestObjectiveManager.gd` | Read-only `get_quest_definition()`; no objective/reward rules changed. |
| `Autoload/FishingManager.gd` | Read-only `is_fishing()` so the menu cannot interrupt a cast or reinforcement; fishing and DDA rules unchanged. |
| `Autoload/SaveManager.gd` | Optional reset-on-missing-section support for older saves; existing registration and restoration architecture preserved. |
| `project.godot` | Registers CodexManager after the existing managers. Existing GUT enablement is preserved. |
| `Scene/Regions/main.tscn` | Adds the single persistent Codex scene after Inventory. |
| `Scene/UI/inventory_ui.tscn` | Adds the Learning Codex button. |
| `Scripts/Systems/Inventory/inventory_ui.gd` | Connects the button to the open request signal. |
| `test/unit/test_codex_manager.gd` | Catalog validation, quest events, data corruption, persistence and legacy-save tests. |
| `test/unit/test_codex_ui.gd` | Inventory entry, locked/unlocked rendering, close/reopen, input safety, missing image and responsive-layout tests. |
| `test/unit/test_codex_data.gd` | Loads imported Texture2D resources instead of raw PNG image files, matching runtime/export behavior. |
| `Resources/Codex/README.md` | Points content documentation to this implemented runtime and its remaining configuration needs. |
| `docs/CODEX_SYSTEM.md` | This implementation, validation and handoff guide. |

Godot may generate `.gd.uid` companion files for new scripts. Existing lesson JSON, source PDFs, images, gameplay/DDA rules, prior fixes, untracked work and other Git changes were preserved. No dependencies were installed. No commit or push was made.

## Validation and remaining issues

Automated verification used Godot **4.5.1 stable .NET**, GUT **9.5.0**, and the existing GDScript Toolkit environment. The full suite passes **41 tests / 999 assertions**, including all original regression tests. The new scripts and Codex tests parse and lint successfully. Expected diagnostic tests intentionally log malformed-file/unknown-ID warnings, and the existing save regression intentionally logs an unavailable-provider error; these are asserted expected outcomes, not unhandled failures.

Coverage includes all five JSON modules and 24 lessons; imported image resources; duplicate/missing/malformed records; real quest completion versus start/objective-only/spurious completion; unknown quest refusal; save/load round trips; missing legacy sections; backfill from completed configured quests; unknown saved IDs; locked-click protection; plain-text content/concepts/table/reference rendering; missing-image fallback; Inventory opening; repeated open requests; close/reopen/Escape; pause ownership; fishing/load guards; and portrait/landscape geometry.

Godot also rendered the isolated reader at **1100×720**, **390×844**, and **720×360** using a temporary process-only lesson unlock. Screenshots of locked/unlocked states, a diagram, and both phone orientations were visually inspected. This is automated engine rendering plus visual inspection, not a manual end-to-end game playthrough or a physical Android test. The temporary visual check did not write a save or change production content, and the project renderer setting was not changed.

**Existing startup blocker:** launching Main with the installed Godot 4.5.1 executable reports `Scene/Regions/region_1.tscn:20 - Parse Error`. The scene is already `format=4` in Git HEAD, and it was not changed by this task. The installed engine does not successfully read this existing scene. Full in-world playthrough verification is therefore blocked even though the isolated Codex and regression tests pass. Investigate the scene's authoring engine version and safe compatibility options in a separate task; do not blindly resave or replace the region.

**Remaining configuration/content:** all unlock mappings remain empty by explicit user choice; the missing Module 5 lecture attachments and instructor-review flags from Phase 1 remain unresolved. There is no export preset; a later Android/export task must include non-resource Codex JSON files and test packaged image/resource access. Existing PDF paths are source citations and need not be included for the reader to work.

Recommended next task: resolve the existing Region 1 scene/engine compatibility issue, then manually test **I → Learning Codex → Close** in the restored world. Agree quest-to-lesson mappings separately before enabling any production lesson unlocks.
