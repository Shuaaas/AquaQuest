# Editing the AquaQuest HUD in Godot

Open `res://Scene/UI/GameplayHUD.tscn` and select the **2D** workspace. The HUD now
contains real, owned Control nodes rather than creating the interface at runtime.
The script binds these nodes and updates game information and actions.

## Start here

1. Expand **GameplayHUD > Exploration** in the Scene tree.
2. Select a panel or button.
3. In the Inspector, expand **Layout > Transform** to edit Position and Size.
4. Save the scene, stop the game, and run the main project again to check it.

The saved design uses a 1280x720 reference canvas. Some controls may sit beyond the
project's 1152x648 editor outline; zoom out to see the full reference arrangement.
The running game adapts the reference layout to its actual window size.

| Node | What you can edit |
| --- | --- |
| EquipmentStatus | Equipment panel placement, width, panel texture and padding |
| EquipmentStatus > HBoxContainer | Gap between the equipment button and text |
| EquipmentName / Points | Font size and color; their text comes from game data |
| MenuButton | Menu button position, size, caption and icon |
| CurrentQuest | Quest card position, width, parchment style and padding |
| CurrentQuest > VBoxContainer | Space between header, title and objective preview |
| QuestTitle / QuestObjective | Fonts and colors; text comes from active quests |
| QuestHeader | Gap between the quest icon, heading and collapse button |
| RegionBadge | Location badge placement, size, style and padding |
| MiniMapSlot | Live minimap placement and size (keep it square) |
| MiniMapSlot > MiniMapFrame | Decorative ring, using the existing drawing component |
| ExploreButton | Explore button placement, size, caption and styles |
| VirtualJoystick / ContextInteraction | Touch control rectangles; visuals use custom drawing scripts |
| HUDMenu > FieldGuideActions | Field Guide button spacing and title |
| CodexButton / InventoryButton / QuestsButton | Text-only shortcut styles and sizes |

## Spacing and styles

For an HBoxContainer or VBoxContainer, use **Theme Overrides > Constants > Separation**.
Containers arrange their children automatically: edit separation, size flags and
minimum sizes instead of dragging a container-controlled label.

For a panel, use **Theme Overrides > Styles > Panel**. Expand its StyleBox resource
and edit Content Margins for internal padding. The wood/parchment textures and
nine-slice settings are saved in the scene. Keep the texture margins intact unless
you are intentionally changing the frame corners. Buttons have Normal, Hover,
Pressed, Disabled and Focus styles. Use **Make Unique** before editing a shared
resource when you want the change to affect only one control.

For a label, use **Theme Overrides > Colors / Font Sizes**. Keep the existing palette
and enough contrast. The responsive layout reduces quest title/heading sizes on
small screens relative to the font sizes you save in the Inspector.

The equipment icon, points, region name, quest text, collapse state and contextual
Talk/Fish prompt are live game data. Editing placeholder text does not replace those
runtime values. The minimap terrain and markers still come from the existing sibling
MiniMapUI scene, not a second map implementation.

## Responsive layout versus fully manual layout

Select the **GameplayHUD** root. **Responsive Layout** is enabled by default.
Saved position and size changes are applied as adjustments to the existing mobile
layout. For example, moving MenuButton 10 pixels right in the scene also moves it
10 logical pixels right in the responsive layout. Refreshes do not accumulate this
movement. Internal container spacing and style changes remain yours.

Leave the `responsive_origin` and `responsive_size` Metadata values alone: these
record the original template bounds. Save changes to Layout Position/Size instead.
After major changes, test several window sizes because authored adjustments can
push controls outside safe areas or cause overlaps.

Turn **Responsive Layout** off for full manual control through anchors, offsets,
containers and minimum sizes. The script then stops repositioning/resizing panels.
You become responsible for responsive placement, screen safe areas and touch target
sizes. The minimap still follows MiniMapSlot. Touch visibility still follows Touch
Controls Mode; normal dialogue/fishing/pause visibility rules remain active.

HUDMenu and MenuShade are intentionally hidden when the scene opens. Toggle their
eye icons temporarily to design the Field Guide, then restore both to hidden before
saving. To preview all touch graphics after changing a drawing script, reopen the
scene/project if Godot has retained an older script preview. Their drawing code and
input behavior are retained; editor preview scripts do not capture editor input.

Preserve the unique node names marked with the percent sign: the HUD script uses
them to find controls. Do not disconnect or duplicate the HUD systems. Existing
weather/time/calendar and minimap-expand controls remain removed, and Field Guide
shortcuts remain text-only.

## Validation for this conversion

Godot 4.5.1: 22 HUD tests pass (478 assertions). Tests cover saved node ownership,
spacing/style persistence, non-accumulating responsive adjustments, manual layout,
existing shortcuts, keyboard/touch input, quest text and multi-resolution bounds.
A separate temporary scene with modified saved MenuButton offsets confirmed that
Inspector-style edits survive repeated refreshes. Full suite: 113/116 pass; the three
existing Region 1 layout failures remain outside this task.

The actual editor scene tree and 2D preview were inspected. Game renders were checked
at 856x428, 1280x720, 1920x1080 and 598x896, with captures also made at 1152x648 and
mobile density. Actual Android device/notch/multitouch testing remains manual.

## Files changed
- Scene/UI/GameplayHUD.tscn: saved Control hierarchy, styles and reference bounds.
- Scripts/UI/GameplayHUD.gd: scene binding and authored responsive adjustments.
- Scripts/UI/HUDReferenceOrnament.gd: Inspector options and editor drawing preview.
- Scripts/UI/VirtualJoystick.gd and HUDTouchButton.gd: editor preview support and editor-input guards.
- test/unit/test_gameplay_hud.gd: four additional conversion/editing checks.
- docs/REFERENCE_HUD.md and this guide: current editing instructions.

No managers, game rules, region scenes, project settings, assets or dependencies
were changed by this conversion. The pre-existing Git work was preserved.

## Soft wooden finish — 2026-11-03
The HUD now uses rounded frames, a gentle upper wood highlight, darkened edges,
and blended brown/gold rims. The three existing nine-slice SVGs retain their paths
and margins; `parchment.svg` now provides the warm wooden quest background.
Quest text and points use cream for contrast. The scene's embedded font uses
grayscale antialiasing, and linear filtering applies only to the HUD. World art
keeps its existing rendering. Minimap/joystick outlines use antialiased arcs; touch
input and actions are unchanged. Field Guide focus keeps a visible outline and
cream text. The removed controls remain removed.

Changed in this finish: Assets/UI/HUDReference/{wood,button,parchment}.svg,
Scene/UI/GameplayHUD.tscn, Scripts/UI/HUDReferenceOrnament.gd, HUDTouchButton.gd,
VirtualJoystick.gd, and this guide. No layout or game rules changed.
Cream #F0DEC1 has at least 5.95:1 contrast against the brightest authored wood
stop #6B4B32 (solid-color calculation; gradients and edges vary).
All 22 existing HUD tests pass. Godot MCP confirms the loaded font is antialiased
and the HUD uses linear filtering; game captures cover small landscape, desktop,
portrait and density previews. Android device testing remains manual.

## Minimap player arrow
The arrow is 25% larger and smoothly turns toward the existing player facing
using frame-rate-independent interpolation. It retains its last idle direction.
Player/camera position and facing update each frame; other map markers retain
their 0.1-second refresh interval. Adjust Player Arrow Scale on MiniMapUI >
MarkerSurface for its size. No player movement rules were changed.

## Quest parchment and sidebar tab
The quest card uses a cream-to-tan parchment body and dark brown title/objective
text, beneath its retained brown header. CollapseQuest is now a sibling of the
quest card under Exploration, so it stays accessible when the card is hidden.
Its slim brown tab has a 48x48 logical hit area and a sidebar icon, not a minus sign.
Clicking again restores the same quest content without pausing gameplay.
It remains editable in the scene; fully manual layout preserves its saved rectangle.
Changed files: GameplayHUD.gd, GameplayHUD.tscn, parchment.svg, the two new
sidebar-collapse.svg/sidebar-expand.svg icons (plus generated import metadata),
test_gameplay_hud.gd and this guide. All 28 HUD tests pass. Live collapse/reopen and
desktop/small-screen captures were checked. Android device testing remains manual.
