# Region Map

Click the circular minimap to open the current Region Map. World Map opens the existing island overview. Back/Escape from that overview returns to the Region Map; Back/Escape again resumes gameplay. Existing direct World Map shortcuts (M and Explore) remain available.

The Region Map renders the live region terrain in an independent SubViewport camera, sharing the player's World2D without cloning game nodes or changing the player's camera. It fits bounds measured from the actual TileMapLayers, player and relevant interactables. Uncharted space uses the reference water blue (#3E92D1). This is an accurate terrain overview, not newly authored illustrated map artwork.

Drag with mouse or one finger to pan. Use the zoom buttons, mouse wheel, +/− keys or trackpad magnification to zoom; arrow keys pan and You/Space centres on the player. Zoom and panning stay bounded by the real map. Clicking a marker displays its existing label; no travel or quest actions are performed. Markers and the You arrow share the same world-to-map transform as the terrain camera.

MapManager and MapNavigation remain the sources of existing NPC, shop, fishing, exit, custom location and active quest markers. An optional marker limit lets the Region Map request all current-region markers; the minimap default remains 12. There are no invented destinations, quests, fog-of-war discovery rules, teleports, unlocks or save sections.

## Files and editing

- `Scene/UI/RegionMapUI.tscn`: native editable wood frame, heading, toolbar, terrain stage, selection and legend.
- `Scripts/UI/RegionMapUI.gd`: view lifecycle, pause/focus ownership, bounds, pan/zoom, World Map handoff and resource cleanup.
- `Scripts/UI/RegionMapSurface.gd`: marker drawing, player arrow, pointer input and marker hit testing.
- `Scene/Regions/main.tscn`: one persistent RegionMapUI instance beside the existing WorldMapUI.
- `Autoload/EventBus.gd`: region_map_open_requested signal.
- `Scene/UI/MiniMapUI.tscn`, `Scripts/UI/MiniMapUI.gd`: full minimap click target and region-map request.
- `Autoload/MapManager.gd`, `Scripts/Systems/Map/MapNavigation.gd`: optional marker limit, with existing default behavior preserved.

The UI uses the same wood/button textures and bundled smooth font family as the newer interfaces. Toolbar controls remain touch-sized; secondary help/legend text is omitted on short landscape screens. Rendering is capped to 1280×720 and disabled when the Region Map is closed. The view refuses to interrupt dialogue, fishing, loading, other overlays or an existing foreign pause. Region changes/scene loads close the view. It releases only the pause it owns.

## Validation

Focused GUT tests cover minimap routing, a single persistent instance, pause/focus safety, World Map return navigation, full marker queries versus the existing minimap limit, mouse/touch input, marker selection, keyboard navigation, projection, rendering shutdown and responsive bounds. Real Region 1 terrain was rendered at desktop, short landscape and phone dimensions. Region 2 was also opened and rendered in an isolated test process, without saving any unlock changes. Godot MCP was unavailable because another client was connected; it was left unchanged. Physical Android touch, pinch behavior and display safe areas remain manual checks.
