# Coastal atlas World Map

The approved coastal concept is implemented in the existing WorldMapUI scene. The
map remains a read-only regional atlas: selecting a region never unlocks it, changes
quests, spends/awards points or moves the player. Travel still uses existing region
exits. No fast-travel, pan/zoom system or new playable geography was added.

## Presentation and live state

The new coastal_islands.png contains five original AI-generated island illustrations
in a 3x2 atlas. It is a regional overview, not a literal rendering of the level scenes.
The built-in image-generation tool was used; no external tools/plugins were installed.
The production asset is copied into Assets/UI/WorldMap. The original output remains
in the Codex generated-images folder. Full final generation prompt and cell order
are recorded in Assets/UI/WorldMap/README.md.

Each island is a native TextureRect/AtlasTexture scene node. Map positions and module
mapping come from the unchanged world_map.json metadata. A per-island ShaderMaterial
applies locked/unavailable desaturation and a gold selected-coast outline. Locks,
current-region arrow, availability text, route dots and region labels are live UI;
no progress state or text is baked into the artwork. The player arrow indicates the
current REGION, not the player's exact position inside its level. The minimap keeps
its existing actual player/terrain behavior.

The PNG has soft low-alpha colored glow, which the shader trims before rendering.
Native labels, readable text and touch targets stay independent of artwork scaling.
The atlas has muted teal water, shared warm wooden frames and a parchment detail card.
All static controls and island textures are editable in the Godot scene. Label data
is populated at runtime from existing managers.

## Layout and controls

- Close, M and Escape retain pause ownership and focus restoration.
- Click/tap an island or its label to select it and reveal its information.
- Details hides/reopens the parchment card. Region name, module, unlock/current/
  completed/undefined status, quest counts, exam state, description and travel note
  use existing MapManager data.
- Native map labels show region names and modules on desktop. Compact screens show
  short region labels plus an accessible region dropdown containing all five choices.
- The card is compact and scrollable; labels avoid it in the normal layout. On short
  screens it starts hidden to maximize map space. Explicitly requesting details opens
  it as an overlay; the dropdown still selects any region, and Details closes it.
- Portrait keeps the map and bottom card usable. Unavailable text plaques hide on
  small maps to avoid crowding; lock icons and the card retain actual status.

Data mappings remain Region 1 → Module 2, Region 2 → Module 3, Region 3 → Module 4,
Region 4 → Module 5, Region 5 → Module 1. Undefined regions remain unavailable. Region 2
currently shares the name Coastal Village in existing region data; this task preserves
that authored name and distinguishes it with its region/module number.

## Edit in Godot

Open Scene/UI/WorldMapUI.tscn, 2D workspace:
- Margin > Panel > Book > Header: title, compact region selector, Details and Close.
- Book > MapColumns > AtlasStage > MapCanvas: ocean and five native Island nodes.
- Each Island has an AtlasTexture cell and independent state material. Serialized
  material values are editor preview defaults; runtime state always comes from
  MapManager. WorldMapCanvas.gd duplicates materials per live screen.
- MapCanvas > RegionButtons is populated with native selectable labels at runtime.
- AtlasStage > RegionCard contains preview, actual region/module/status and InfoScroll.
- Book > Legend explains player/selection/lock markers and region-exit travel.

The local Theme reuses existing wood/button/parchment SVGs. The font family remains
Godot's existing bundled fallback, using grayscale antialiasing for map labels/card
readability. Shared UI themes are unchanged. Responsive code positions the artwork,
labels and card. Do not edit gameplay coordinates or mappings to move illustrative
pixels. Change atlas artwork or the presentation component for art/layout adjustments.

## Files changed

- Scene/UI/WorldMapUI.tscn: native atlas hierarchy, local styling, card and controls.
- Scripts/UI/WorldMapUI.gd: region labels, dropdown, detail presentation and responsiveness.
- Scripts/UI/WorldMapCanvas.gd: atlas illustration/state presentation and hit testing.
- test/unit/test_map_system.gd: four additional atlas tests.
- Assets/UI/WorldMap/coastal_islands.png and generated import metadata: new artwork.
- Assets/UI/WorldMap/island_state.gdshader and its UID: live state/outline rendering.
- Assets/UI/WorldMap/README.md: asset provenance and final generation prompt.
- docs/COASTAL_ATLAS.md: this guide.

No managers, data JSON, region scenes, quest/exam logic, scoring/DDA, player scripts,
project settings, save schemas or existing MCP configuration were modified.

## Validation

Godot 4.5.1: all 22 map-system tests pass. Existing tests cover module mappings,
selection without travel/unlocks, M/Escape/open reuse, actual exam progression,
minimap markers and save reconstruction. New checks cover live artwork states,
card/control bounds across resizing, native targets, mouse/touch selection, and the
short-screen dropdown/Details card without progression changes.

Full suite: 136/139 pass. The same three pre-existing Region 1 layout failures remain
at test/unit/test_region1_layout.gd:106,170,189–190. No new UI failures.
Desktop native renders checked at 1280x800, 1152x648, 720x360 and 390x844, including
an undefined-region card. OpenGL compatibility rendering completed without script or
shader errors; the real main editor/project also loads the scene through Godot MCP.
Actual Android GPU, physical touch targets, display cutouts and reading comfort still
need manual device testing. The generated illustration is intentionally separate
from playable terrain; it does not establish new world locations or educational facts.
