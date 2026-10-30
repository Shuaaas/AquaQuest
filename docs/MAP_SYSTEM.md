# AquaQuest world map and mini map

Implemented 2026-10-30 for Godot 4.5.1 / GDScript. This system reads the existing regions, quests, exam history and current scene. It does not award progress, create playable regions, introduce fast travel, or change fishing/DDA rules.

## Controls and player behavior

- **M** opens the world map during normal gameplay; **M**, **Escape**, or **Close** closes it.
- The mini map's **Map** button provides the same entry point on touchscreens.
- Click/tap an island or use the five **R1–R5** buttons to select a region. Selection only shows information. It never teleports, unlocks, or starts a quest.
- **N** still saves. The previous M-to-load shortcut is now **Ctrl+M**, preserving load access while meeting the requested map shortcut.
- Close Inventory, Codex, Performance Board, dialogue, shop, fishing or exam interfaces before opening the atlas. A blocked request leaves those interfaces and their pause state intact.

The atlas is one persistent UI instance in Main's CanvasLayer. It pauses gameplay through GameManager and continues processing its own buttons. Closing/removing it releases the pause it acquired and restores the prior GUI focus. Repeated open requests reuse it.

## Five regions and visual themes

| Region | Module, read from Codex content | Illustrated environment | Actual world status |
| --- | --- | --- | --- |
| 1 | Module 2 — Fish and Other Aquatic Species as Raw Material | Coastal landing village, fishing boat, docks and vegetation | Existing Region 1 scene and definition. |
| 2 | Module 3 — Fish Spoilage | River/wetland shore with shaded vegetation | Existing Region 2 scene and definition. |
| 3 | Module 4 — Traditional Fish Processing Methods | Warm-colored shore, drying racks and processing sheds | Planned region; no playable definition yet. |
| 4 | Module 5 — Methods of Fish Preservation | Cool-colored shore, storage buildings and pale storage crates | Planned region; no playable definition yet. |
| 5 | Module 1 — Introduction to Post-Harvest Fisheries | Connected islands, market buildings and docks | Planned region; no playable definition yet. |

These are decorative interpretations of the actual documented topics, not new educational claims or new playable environments. Module titles/content come from the existing Codex JSON. The overview is composed on a pixel grid and reuses the project's existing tree atlas. No image pack, plugin, AI image, or external dependency is required. The sea routes are an illustrated overview of the five-region plan, not a new travel mechanic or a claim that future exits already exist.

Region names/descriptions come directly from RegionManager. Both existing regions currently share the name Coastal Village; the UI includes their region numbers to distinguish them. Regions 3–5 are visibly locked and not yet available. No fabricated region names, quests, exams, or completed counts are supplied for them.

## World-map progress and progression

MapManager reads `RegionManager.is_region_unlocked()` and `current_region_id` for status. Main already unlocks Region 1 at startup. ExamManager's existing passed-exam path unlocks Region 2; no new progression threshold is implemented in the maps. Changes arrive through EventBus's existing region, quest, exam and load signals, then the additive `map_data_changed` signal refreshes the visible atlas.

The atlas displays the region/module, description, unlock/current/completed status, completed/total main quests, available quests and regional exam status where an exam exists. A completed region requires at least one configured main quest, all of its main quests completed, all authored regional exams passed, and an unlocked region. Zero-quest regions are never labeled completed automatically.

Regional quest ownership is presentation metadata in `Data/JSON/Maps/world_map.json`. The initial configuration associates `learn_post_harvest_basics` with Region 1 (the teacher's real quest) and `visit_region2_mini` with Region 2 (its actual visit objective). Available quests means active quests plus unstarted quests available under the currently authored region unlock and quest-chain rules. A chained quest is not counted before its real predecessor completes. Completed/failed quests are not counted as available. Extend this presentation metadata alongside future actual quest definitions; it does not assign or complete quests itself.

There is no established fast-travel feature in the inspected project. The atlas therefore has no travel button. Existing RegionExit nodes still enforce quest and region gates and call RegionManager to travel.

## Mini-map terrain and coordinate tracking

The upper-right HUD contains a small SubViewport and Camera2D sharing the local player's actual World2D. This renders the surrounding real terrain and world sprites rather than showing a static mock map. A separate marker overlay uses the same projection:

```text
map_position = map_size / 2 + (world_position - player_position) * map_width / (2 * world_radius)
```

The camera zoom uses that same factor. `MiniMapUI.world_radius` controls the horizontal half-width of the visible world area (default 280 world units). The vertical extent follows the mini-map aspect ratio. Player/camera/marker positions refresh at 10 Hz; pause and activity visibility changes are handled immediately, with overlay/loading guards checked every frame. Rendering is disabled while hidden.

Only the one current scene under the existing `region_container` is queried. During background loading or save restoration the mini map clears/hides; it resolves the new local Player and region root afterward. NPCs/locations outside that region never enter the marker list. Markers are rebuilt from live nodes, keyed by instance ID, and do not retain old Node references, so repeated queries and scene transitions do not accumulate duplicates.

The inspected project has no fog-of-war or exploration state. None was introduced.

## Markers and quest navigation

| Marker | Meaning and source |
| --- | --- |
| White arrow | Local player's current position at the center. |
| Cyan square | Enabled NPC in the current region. |
| Gold exclamation | Pending active main-quest objective or its turn-in NPC. |
| Violet exclamation | Pending active mini-quest objective. |
| Blue square | Actual enabled FishingSpot. |
| Orange square | Merchant NPC / authored shop marker. |
| Light-green square | Examiner NPC / authored exam marker. |
| Teal square | Actual region exit. |
| Pale square | Optional important location, such as a dock. |
| Colored edge arrow | Active objective outside the displayed mini-map extent. |

Navigation asks QuestObjectiveManager for pending objectives. This read-only API uses the same existing DDA-aware required-count function as quest completion; no objective-count formula is duplicated in the map.

- Catch/answer objectives highlight matching enabled fishing nodes. Fish IDs follow the actual spot override, fishing-area species, and generic-fish fallback rules.
- Visit objectives highlight actual RegionExit nodes. If the target is locked behind an authored regional exam, the guide highlights its mapped real examiner first, then switches to the exit once the region unlocks. It does not draw a route into a locked region as if it were open.
- Exam objectives highlight the configured real examiner NPC.
- When `objectives_complete` is set, the real mapped quest giver becomes the return target. Completed/failed quests stop generating quest markers. If a turn-in NPC is not configured or present, the map does not invent one.
- Fishing reinforcement signals temporarily associate the mini-quest marker with the actual fishing spot and clear it when the main question resumes or fishing ends. Because the existing reinforcement activity is a stationary question interaction, the HUD hides during its question panel. No fictional spatial reinforcement task was created. The separate Scout Ahead mini quest remains visible as a navigable violet objective during gameplay.

Active objectives have highest priority and may be shown as edge arrows even when distant. Non-objective points are limited to the configured nearby radius. At most 12 markers are returned, favoring active objectives and then nearby locations. The map does not expose distant unrelated NPCs just to fill the HUD.

## Authoring coordinates and placing markers

1. **Overview coordinates:** edit a region's `position` in `Data/JSON/Maps/world_map.json`. Values are normalized `[x, y]` from 0 to 1 within the illustrated atlas. These positions place island art; they are not player world coordinates. Preserve the approved region/module IDs.
2. **Region names and gameplay:** continue defining actual scenes and descriptions in `Data/JSON/Regions/`. Map metadata does not replace those definitions or unlock missing regions.
3. **Existing points:** NPC, FishingSpot and RegionExit nodes are discovered automatically at their actual `global_position`. Move their real nodes in the level editor to change their map positions. No additional marker is needed for them.
4. **Additional locations:** add a Marker2D to the region scene and attach `Scripts/Systems/Map/MapLocation.gd`. Set `title`, `marker_kind`, and its normal editor position. This can mark a dock, processing building or other real location.
5. **Precise objectives:** optionally set that marker's real `quest_id` and `objective_index` (zero-based; -1 means any pending objective). It appears only while that quest/objective is active and pending. Do not create a new quest merely to place a marker.
6. **Quest owners and examiners:** extend `quest_givers` and `exam_npcs` in map JSON with IDs verified in actual NPC dialogue/definitions. These map an existing quest/exam to an existing local NPC, not to invented coordinates.
7. **Regional progress:** list actual quest IDs under the appropriate region's `quest_ids`. The main/mini classification is read from each quest's existing definition.

## File inventory

New files:

| File | Purpose |
| --- | --- |
| `Autoload/MapManager.gd` | One read-only coordinator for regional map data, progress, live region/player resolution and event refresh. |
| `Data/JSON/Maps/world_map.json` | Five island positions, approved module mappings, quest ownership and real giver/examiner IDs. |
| `Scripts/Systems/Map/MapNavigation.gd` | Stateless live-node discovery, objective resolution, priorities and coordinate projection. |
| `Scripts/Systems/Map/MapLocation.gd` | Optional editor-placed location/objective marker data. |
| `Scripts/UI/WorldMapCanvas.gd` | Interactive pixel-grid island illustration using existing tree artwork. |
| `Scripts/UI/WorldMapUI.gd` | Atlas selection/details, open/close, responsive layout and pause ownership. |
| `Scripts/UI/MiniMapUI.gd` | HUD visibility, small live-world viewport, player camera and marker refresh. |
| `Scripts/UI/MiniMapSurface.gd` | Player/POI/quest icons and off-screen objective arrows. |
| `Scene/UI/WorldMapUI.tscn` | Persistent atlas screen and accessible region-selection buttons. |
| `Scene/UI/MiniMapUI.tscn` | Upper-right HUD, expansion button, terrain viewport and marker layer. |
| `test/unit/test_map_system.gd` | Map data, controls, quests/exams, viewport/marker, scene, save and layout regressions. |
| `docs/MAP_SYSTEM.md` | This implementation and authoring guide. |

Modified files:

| File | Purpose |
| --- | --- |
| `Autoload/EventBus.gd` | Adds `world_map_open_requested` and `map_data_changed`. |
| `Autoload/QuestObjectiveManager.gd` | Read-only definition list and pending-objective query, reusing existing completion counts. |
| `Autoload/ExamManager.gd` | Read-only exam-definition list for map progress and examiner navigation. |
| `project.godot` | Registers MapManager after existing managers. |
| `Scene/Regions/main.tscn` | Adds one atlas and one mini map; tags existing overlay instances for input/visibility guards. |
| `Scripts/Managers/main.gd` | M opens map; Ctrl+M retains the existing load action. |
| `docs/CODEX_SYSTEM.md` | Updates load shortcut and corrects the earlier premature-shutdown startup diagnosis. |
| `Resources/Codex/README.md` | Corrects its reference to the superseded scene-startup diagnosis. |

Godot may create `.gd.uid` companion files for the new scripts. No save-format change, map-specific save section, database, plugin or new external asset was added. Regions, quests, dialogue, educational content, rewards, scoring and DDA behavior remain owned by their existing systems.

## Verification and remaining work

The complete GUT suite and new-script lint checks were run using the installed Godot 4.5.1 stable .NET, GUT 9.5.0 and GDScript Toolkit. See the final validation count appended below. Expected negative-test diagnostics remain explicitly asserted; no unhandled script errors or orphaned map nodes are accepted.

Automated coverage includes all five mappings, unavailable regions, locked selection, M/close/Escape/reopen, real exam completion and Region 2 unlock, real quest counts/availability, world-coordinate projection, fishing and turn-in targets, gated routes/examiner guidance, mini-quest/reinforcement lifecycle, disabled/wrong-fish spots, cross-region exclusion, marker limits/priorities, custom markers, scene replacement, existing save restoration, overlay/pause conflicts, and portrait/landscape geometry.

Godot rendered the real Main scene and production Region 1 at 1200×760, 390×844 and 720×360. The atlas and live mini map were visually inspected. The render check used a one-off Compatibility renderer CLI argument; the project's Mobile renderer setting was not changed. A temporary quest was started in that process solely to inspect objective markers; it did not save progress. A controlled test region was used during earlier isolated checks, but final screenshots use the existing production region.

**Correction to the previous startup finding:** Region 1 loads successfully when its background load is allowed to finish. Earlier parse-error messages occurred during an excessively short test shutdown, so a Region 1 format conversion is not warranted by that evidence. No region or NPC scene was rewritten. A real existing warning remains: Region 1 lacks a `default` spawn point, so SpawnPointComponent retains the player's existing position. Address that as a separate level-authoring task if a different start position is intended.

Remaining authoring/validation tasks:

- Build real Regions 3–5 and their actual quests, exits and examinations before their planned map entries can become playable. The maps do not fabricate these systems.
- Optionally replace/refine the procedural overview artwork; the provided artwork already runs using existing assets, so no manual import is required to use the system.
- Perform a manual end-to-end playthrough and physical Android tests, including touch input, small-screen readability and the extra viewport's performance. Automated rendering is not a substitute for those tests.
- No export preset currently exists. When packaging, include non-resource JSON from `Data/JSON/Maps/` and the game's other JSON folders, and test resource access in the actual exported build. Existing texture imports are used normally.
- Update map navigation metadata alongside future NPC/dialogue/quest changes. Unmapped future objective types/turn-in NPCs are not invented by the navigator.

Final automated result: **64 tests passed / 1183 assertions**, exit code 0; new map scripts/tests lint clean.
