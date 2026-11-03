# Region 1 coastal village redesign

## Scope and inspected scene

Region 1 remains the existing Coastal Village associated with Module 2. The redesign changes scenery and walking landmarks, not educational content or progression rules.

The original `Scene/Regions/region_1.tscn` has no root script. Its seven original TileMapLayers are retained: `grass` (hidden), `ground`, `water`, `rockLayer2`, `rock`, `shadow` (empty), and `props` (hidden). Hidden layers were not enabled: visibility alone does not establish that their old collision or decoration layout is suitable.

The original TileSets contain atlas sources for floors, walls, water, wall variations, trees, building shadows, building props, vegetation and rocks. Most terrain uses 16×16 tiles. The water's shore cells and cliff layers contain collision polygons. Their original serialized TileMap data, TileSets and atlas definitions were compared with the pre-edit scene and remain unchanged. Texture imports use the existing lossless settings without mipmaps; import settings and source artwork were not edited.

## Environment changes

- Earth paths with native grass borders connect spawn, Teacher Ana, the examiner, Merchant Lola, the landing and the central working square. A southern return route forms a village loop.
- Sand margins follow the original irregular pond/coastal outline. The collision-bearing shoreline itself was preserved rather than repainted into an incompatible shape.
- A timber landing deck marks the accessible bank inside the existing FishingSpot's interaction range. It sits on dry land; this is not a new walkable bridge across collision water.
- Two fisher houses, a handling shed and a storage building make the previously empty grass read as a settlement. Buildings are decorative, with solid footprints and no invented interiors or actions. The storage roof uses the existing turquoise variation to distinguish it. Complete six-row roofs, native timber gables and pack windows complete the facades.
- Market/work tables, native pack buckets, crates and barrels suggest landing, storage and trade. The merchant approach uses stone paving. They introduce no processing, selling or quest rules.
- Trees, shrubs and rocks frame the coast and settlement while leaving the routes open. Low vegetation is decorative; large props have explicit static collision footprints.
- A tiled water backdrop replaces the gray void beyond the map. Four new outer safety boundaries prevent walking beyond its original extent. Original water/cliff collisions are retained.
- Small location signs identify the market, landing, handling/storage buildings and existing Region 2 route. They are labels, not new interactable lessons.

The added environment is a static, editable subscene, `Scene/Regions/Region1Village.tscn`, instanced as `VillageEnvironment`. Its `CoastalBackdrop`, `ShoreSand`, `VillagePaths`, `LandingDecks` and `VillageRoofs` TileMapLayers have separate TileSets using existing textures. `ShoreTransitions`, `PathTransitions`, `MarketPaving` and `MarketTransitions` add native grass borders and a distinct merchant approach; their TileSets are embedded in the same scene. Existing TileSets were neither replaced nor shared with modified physics data. `VillageScenery` holds original-sheet sprite regions and labels; StaticBody2D nodes hold new prop footprints and edge guards. No runtime generation script or new manager is needed.

## Gameplay anchors preserved

| Existing node | Position | Connection retained |
| --- | --- | --- |
| `player` | `(0, 0)` | Existing movement, interaction, camera, fishing, equipment and persistence components |
| `NPC_teacher` | `(-458, 84)` | Existing Teacher Ana dialogue and quest actions |
| `Npc_examiner_santaigo` | `(-153, -44)` | Existing examiner dialogue and exam gate |
| `npc_merchant_lola` | `(133, -38)` | Existing merchant dialogue and `general_store` |
| `FishingSpot` | `(-626, 157)` | Existing rotation, radius, quest gate, `region1_dock_north`, and rod requirement |
| `RegionExit` | `(-232, -98)` | Existing Region 2 destination and `west_entrance` destination spawn |

No existing gameplay object was moved, renamed or removed. A `DefaultSpawn` Marker2D at `(0, 0)` uses the existing PlayerSpawnPoint script and is placed before the player in scene order. This resolves the previously missing default marker without changing the initial player location. Existing serialized node blocks and subresource blocks match the pre-edit snapshot.

## Reused assets and art needs

All assets already existed:

- `Assets/Environment/Tilesets/Floors_Tiles.png` and `Water_tiles.png` for sand and sea.
- `Assets/Environment/Structures/Buildings/Roofs.png`, `Walls.png` and `Props.png` for buildings and landing posts.
- `Assets/Environment/Props/Static/Furniture.png` for timber decks, tables, crates and barrels.
- `Assets/Environment/Props/Static/Trees/Model_01/Size_04.png`, `Vegetation.png` and `Rocks.png` for scenery.
- `Assets/Environment/Props/Static/Trees/Model_01/Size_03.png` for smaller complete green trees.

The earlier UI fish-symbol decorations have been replaced with native pack containers. No UI texture is used as world scenery, and no sprite is scaled away from its native dimensions.

No new texture, external asset pack or dependency was added. No suitable boat sprite was found in the inspected folders. A matching fishing-boat spritesheet is a separate future art need if visible boats are required; none was silently replaced with a placeholder. The scenery does not claim that new landing/storage gameplay is implemented.

## Files changed in the initial layout pass

1. `Scene/Regions/region_1.tscn`: two resource references, the spawn marker and the environment instance; original gameplay/layer blocks retained.
2. `Scene/Regions/Region1Village.tscn`: new static environment subscene.
3. `test/unit/test_region1_layout.gd`: six integration tests.
4. `docs/REGION1_REDESIGN.md`: this report.

Godot may generate script UID metadata. Other regions, gameplay scripts, managers, educational JSON, project settings, original images and existing Git changes were preserved. Nothing was committed or pushed.

## Validation

Godot 4.5.1 loaded the scene and all referenced resources. The full GUT suite passed: **84 tests, 2,291 assertions**. The seven Region 1 tests cover anchor preservation, routes, NPC interactions/dialogue, fishing gating/start, outer edge collisions, the existing movement controller's movement/stopping, and native asset/atlas validation.

Route checks use the real player's capsule, its collision offset, physics queries and swept motion on a 16-pixel grid. CharacterBody2D traversal then checks the computed routes, rather than merely treating painted sand as passable. Reachable approaches are within about 14 pixels of each NPC and 9 pixels of the exit. The fishing-bank approach at `(-512, 160)` is about 114 pixels from the unchanged spot center and overlaps its existing interaction area. Tests exercise the existing interaction component to open all three dialogues; fishing is denied before its quest and starts after configuring its existing quest/rod prerequisites in memory.

Engine-rendered visual checks include a whole-map overview, the production Main scene at spawn, the landing and market through the existing camera, and a 390×844 phone viewport. The live minimap renders the new scenery through its existing world viewport. Compatibility rendering was selected only for the check process; project renderer settings were not changed. The new test script passes GDScript Toolkit linting and the diff passes whitespace checks.

These automated checks are not a complete manual playthrough. Remaining manual tasks:

1. Walk/run around every building and prop corner, especially the landing and woodland edge; grid route checks cannot establish how every corner feels to a human player.
2. Accept the quest through dialogue, equip the rod, finish a timed fishing/question attempt, turn in the quest, take the exam and use the unlocked transition. The map tests validate access and fishing start; they do not change or certify all existing quest/reward/exam rules.
3. Check camera framing and signs at your target desktop resolutions and on a physical Android device, with inventory, map and question overlays open.
4. Review whether the bank-side landing is sufficient or commission a matching boat/extended-jetty art set. A walkable over-water jetty would require a separately reviewed shoreline collision change.

Warnings about undefined future Codex regions remain pre-existing and outside this map task. The missing default spawn warning is resolved for Region 1's normal default entry.


## Pixel Crawler refinement — 31 October 2026

Reference: [Anokolisa's official Pixel Crawler page](https://anokolisa.itch.io/free-pixel-art-asset-pack-topdown-tileset-rpg-16x16-sprites). Implementation uses the extracted files actually installed in this project; the website is not treated as proof that additional assets are installed. No archive was found in the project and no pack was downloaded or installed.

This refinement modifies only `Scene/Regions/Region1Village.tscn`, `test/unit/test_region1_layout.gd` and this report. The hash comparison against the start of this refinement confirms that `region_1.tscn`, the source textures/import settings, other regions, managers, player scripts and educational data are unchanged. Existing Git status entries were preserved.

### Asset inspection and suitability

| Local artwork | Actual sheet dimensions | Use / suitability |
| --- | --- | --- |
| `Tilesets/Floors_Tiles.png` | 400×416, 16px grid | Green ground masks, earth, stone paving and sand; snow excluded |
| `Tilesets/Water_tiles.png` | 400×400, 16px grid | Existing blue coastal water and shore art |
| `Buildings/Roofs.png` | 400×400, 16px grid | Brown timber roofs and turquoise warehouse roof |
| `Buildings/Walls.png` | 672×800 | Timber facades; full asset sections retained at native size |
| `Buildings/Props.png` | 400×400 | Doors, windows, posts and shutters |
| `Props/Static/Furniture.png` | 800×864, 16px grid | Timber decks, work tables, crates, baskets and buckets |
| `Props/Static/Vegetation.png` | 400×432 | Green shrubs and plants |
| `Props/Static/Rocks.png` | 208×304 | Native rock details |
| `Tavern/Tavern.png` | 1280×1280 | Interior reference only; not cut up to fabricate outdoor facilities |

The pack also contains dungeon, esoteric, furnace/anvil/alchemy and meat assets. These are not substituted for fish-handling equipment or fishing boats. There is no new processing station, lesson, combat object or implied educational claim. Buildings remain scenery rather than newly accessible interiors.

### Verified atlas choices

Coordinates below are source pixels or explicit 16px atlas cells, checked against the local sheets rather than inferred from filenames:

- Earth surface: Floors cell `(12,10)`; sand surface: `(7,23)`; merchant paving: cells `(6,10)` through `(8,10)`.
- Grass transition masks: Floors cells `(1,0)`, `(2,0)`, `(3,0)`, `(0,2)`, `(4,2)`, `(1,4)`, `(2,4)`, `(3,4)`. These overlay the surfaces without changing terrain physics. Earth and sand use consistent base tiles to avoid checkerboard color patches.
- Brown roof: cells `x=0..7, y=0..5`; turquoise roof: `x=8..15, y=0..5`. The eave row is included. Roof placement retains the existing building footprint and keeps existing NPCs clear.
- Timber gable: a triangle sampled from Roofs source pixels `(32,160)`, `(64,144)`, `(96,160)`. Polygon edge lengths match texture UV lengths, so this clips native artwork without stretching it or creating a new image.
- Windows: Props pixel rectangles `(32,96,32,32)` and `(64,96,32,32)` for glass/shutter variants.
- Deck planks: Furniture center cell `(2,36)`, with inspected edge cells `(2,34)`, `(2,38)`, `(1,36)` and `(4,36)`. This removes the earlier repeating interior-edge pattern.
- Native containers: Furniture pixel rectangles `(736,48,16,16)`, `(752,48,16,16)`, `(736,16,16,16)` and `(752,80,16,16)`.
- Smaller green tree: the complete `(0,0,48,96)` region in the actual 208×192 `Trees/Model_01/Size_03.png` sheet. The trunk's world position is retained. No neighboring seasonal tree is included.

New transition/paving TileSets use 16×16 atlas regions and reside inside the existing environment subscene. The original Region 1 collision-bearing TileSets are unchanged. The regression test checks native sprite scale, pack-only texture references, atlas bounds and equal polygon/UV dimensions.

The current render outputs show the complete map, spawn, landing, market and a 390×844 phone viewport using the production camera and live minimap. No full manual timed-fishing/exam playthrough or physical Android test is claimed. The existing manual checklist above remains applicable.
