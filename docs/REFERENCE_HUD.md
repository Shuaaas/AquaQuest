# Reference-image AquaQuest HUD (2026-11-02)

## Implemented structure
The existing Scene/UI/GameplayHUD.tscn and GameplayHUD.gd remain the entry point.
The previous mobile input adapter, menus, quest data adapter and circular live minimap
are retained. This pass replaces the visual chrome and anchored layout to follow the
user's supplied wood/parchment reference, not the scenery in that image.

- Top left: compact wooden equipment/points panel, square equipment inset, and wooden
  knot detail. The actual equipped item and actual spendable points are shown.
- Beneath it: hamburger Menu button; existing Codex, Inventory and Quests routes remain.
- Top right: the existing live circular minimap, new wood/gold rings, existing expand
  action, and current location badge. Marker and terrain logic are unchanged.
- Right side: parchment quest tracker with a purple gem, gold header, dark quest title,
  current objective and foliage accents. The title opens the existing quest board.
  The collapse control remains. Very short screens hide objective detail to fit; the
  full quest board remains available. Quest text/counts still come from HUDStatus and
  QuestObjectiveManager, including existing DDA targets.
- Bottom left: olive/gold joystick with four directional markers. The default hit area
  increased from 144 to 160 logical units; it was not reduced for the visual design.
  Input capture/dead-zone logic and player movement algorithms are unchanged.
- Bottom center: E-keycap interaction prompt, visible only for a valid target. Talk,
  Fish or the existing target prompt feed the same PlayerInputComponent/InteractionComponent.
- Bottom right: Explore opens the existing World Map, as explicitly approved. Previously
  Explore was only a disabled label on the contextual button and had no independent action.

## Palette and reusable art
Scripts/UI/HUDReferenceStyle.gd centralizes the reference HUD palette and reusable
StyleBoxTexture/button styling. Existing UI outside the HUD keeps its current theme.
The HUD uses deep ink #21160F, shadow #302016, panels #3A281C/#4A3020,
wood #76502F/#987044, gold #C6A66A, parchment #E6D2AC, cream #F0DEC1,
muted text #C8B18C, quest gold #D8B84F, quest purple #9560A2,
natural green #718D43 and selected blue #526E78. Actual map terrain is not recolored.

Assets/UI/HUDReference contains eleven original SVG UI assets: wood/button/parchment
nine-slice panels; menu, location, quest, explore, sun, calendar, leaves and knot icons.
These are code-authored pixel-compatible shapes with restrained grain and layered
edges, not cropped environmental tiles or copied image fragments. Existing rod,
Codex/inventory/quest/expand icons and existing aliased fallback font are reused.
Nearest filtering remains. New Godot .import/.uid metadata is normal generated data.

## Deliberately unconnected elements
No clock, calendar progression, or weather system exists in the project.
The reference's weather/calendar chrome is visual-only: disabled weather icon,
time label --:--, and tooltips explaining that they are unconnected. No fake time,
weather state, date, or new gameplay simulation was introduced.

## Files changed in this task
- Scripts/UI/GameplayHUD.gd: visual hierarchy, responsive layout, context visibility,
  Explore/world-map wiring, and reference styles.
- Scripts/UI/VirtualJoystick.gd: drawing only; input handling is retained.
- Scripts/UI/HUDTouchButton.gd: drawing only; independent-finger input is retained.
- test/unit/test_gameplay_hud.gd: requested resolutions, new controls, contextual
  visibility, Explore route and unconnected clock checks.
- docs/MOBILE_HUD.md: points to this current visual design.
New: Scripts/UI/HUDReferenceStyle.gd, Scripts/UI/HUDReferenceOrnament.gd,
Assets/UI/HUDReference/* and this guide, plus generated resource metadata.

No gameplay scene, region, PlayerInputComponent, InteractionComponent, gameplay
manager, project.godot, AGENTS.md, save format, or dependency was changed by this pass.
An unrelated concurrent edit to Scripts/UI/PerformanceBoard.gd was detected and preserved.

## Verification
- Godot 4.5.1: headless import completed; the second validation editor could not bind
  the MCP port already owned by the main editor. The main MCP connection remained live.
  The actual editor's MCP filesystem rescan/reimport also completed successfully.
- 15 HUD GUT tests pass, including independent touch indices, keyboard movement,
  equipment/points/quest binding, menu ownership/handoff, dialogue and fishing/question
  visibility, cleanup, density and layout checks.
- Full suite: 106/109 pass. Three existing Region 1 tests still fail because their
  merchant-position/outer-guard/VillageEnvironment assumptions no longer match the
  saved map (test/unit/test_region1_layout.gd:106,170,189-190). This pass leaves them alone.
- Actual desktop renders inspected at 856x428, 1280x720, 1920x1080 and 598x896, plus
  native 1152x648. Unit layout checks also include older 720x360/390x844 fallbacks.
- Actual Godot MCP: simulated finger input moves the real player at unchanged walk
  speed 120; Explore opens the existing World Map and closes without leaving pause.
- Captures complete without HUD GDScript errors. Existing house-scene UID fallback
  warnings remain. No actual Android build/device testing was performed.

## Reference differences and manual checks
The reference's environment was not recreated. The real region terrain, buildings and
minimap terrain remain the project's own. Quest/equipment text is actual data, not the
reference's example. Chrome uses scalable crisp SVG/nine-slice art and the existing font;
it is not a pixel-for-pixel copy of the reference's illustrated wood/paper textures.
Portrait/short-screen layout adapts spacing and stacks the prompt above bottom controls.
On Android, verify physical touch sizes, notch safe areas, interruptions and multitouch
mouse emulation. Existing Inspector touch preview/density controls remain available.

## HUD refinement — 2026-11-02

This follow-up refines the existing HUD rather than replacing its layout or palette.
Wood/button/parchment frames have approximately 25% thinner visible borders; gold
bands are about one-third thinner. The minimap rings and decorative leaves/knots
are lighter and smaller. Nine-slice corners and nearest filtering remain intact.

The equipment, minimap and quest panels are slightly narrower. Weather/time sit
beside the minimap, with an 8-pixel gap to the location and 12 pixels to the quest
card. Existing safe-area margins and mobile scaling remain. The quest title uses
one or two bounded lines; all objective text remains in a touch-scrollable preview.
Title/header access to the existing journal is preserved. That journal currently
lists known quest IDs/statuses; this visual pass does not implement a richer journal.

The interaction prompt measures its text instead of reserving a fixed wide box.
Talk/Fish/Collect/Inspect/Interact retain their context, with a minimum 128x48 logical
hit area. Styles are cached instead of recreated every draw; focus has a visible outline.
Independent touch indices and movement/interaction handling are unchanged.

Files modified in this refinement:
- Assets/UI/HUDReference/wood.svg
- Assets/UI/HUDReference/button.svg
- Assets/UI/HUDReference/parchment.svg
- Scripts/UI/HUDReferenceOrnament.gd
- Scripts/UI/HUDTouchButton.gd
- Scripts/UI/GameplayHUD.gd
- test/unit/test_gameplay_hud.gd
- docs/REFERENCE_HUD.md

Verification: all 18 HUD tests pass. The full GUT suite passes 109 of 112 tests;
the same three Region 1 layout tests described above still fail. New tests cover
context-sized prompts, long objective scrolling, bounded quest cards, journal access,
and actually visible title/objective lines (not merely assigned text). Desktop renders
were checked at 856x428, 1280x720, 1920x1080, 598x896, and native 1152x648;
layout tests also cover 720x360 and mobile density. Godot MCP loaded the real main
scene with the updated HUD. No new assets, plugins, dependencies or project settings
were required. Clock/weather remain unconnected. Actual Android touch comfort,
notch safe areas and device interruptions still require manual device testing.

## HUD controls removed — user request
Weather and time/calendar panels and the minimap expand button are no longer
created. The minimap, location label, Active Quest card and Explore button remain.
Explore continues to open the existing World Map. Existing icon files are retained.

## Editable scene conversion — 2026-11-03
The HUD controls and their styles now live in Scene/UI/GameplayHUD.tscn.
GameplayHUD.gd binds those saved nodes instead of building them. See EDITING_HUD.md
for Inspector instructions, responsive/manual layout behavior and current validation.
