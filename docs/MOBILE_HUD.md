# Mobile-first AquaQuest HUD (2026-11-02)

> The current reference-image layout is documented in [REFERENCE_HUD.md](REFERENCE_HUD.md). The original mobile input integration below is retained as implementation history.

## What changed
The previous HUD used a large empty equipment medallion, a tall left quest card,
and three permanent menu circles. The existing GameplayHUD scene now builds a
compact native Godot interface with the same brown/gold palette and existing theme.
No project resolution, camera, map, data, scoring, DDA, or save format was changed.

- Top left: actual equipped rod, inventory shortcut, and spendable points. An empty
  48-unit equipment button opens inventory; it does not pretend a rod is equipped.
- Top right: smaller circular live minimap, location, and existing world-map shortcut.
- Bottom center: current quest/objectives, a collapse button, and a quest-board link.
- Bottom left on touch devices: joystick with captured finger index and dead zone.
- Bottom right: contextual Fish/Talk/Interact button; Explore is disabled out of range.
- Menu: Codex, Inventory (including equipment), Quests, Close. Settings were not added
  because the existing project has no functional settings screen.

## Controls and integration
PlayerInputComponent remains the sole adapter to movement and interaction signals.
The joystick supplies a direction there; it never moves CharacterBody2D directly.
MovementComponent still owns acceleration, friction, collision, walk/run speeds,
and normalization. Joystick distance is a dead-zone/sensitivity control, not a new
walking-speed rule. Keyboard input still works and takes priority at full strength.
The contextual button calls request_interact(), which emits the existing signal
connected to InteractionComponent.try_interact(). The focused-target query reuses
its existing nearest-enabled selection. No interaction implementation was duplicated.

Touch controls track separate finger indices so interaction can be pressed while
moving. They consume captured screen-touch events and discard emulated mouse clicks
on the contextual control to prevent duplicate interactions. Hiding the HUD or losing
application focus clears the joystick. Dialogue, fishing, questions, loading, foreign
menus and pause gate gameplay input. The HUD's own menu pauses and releases only its
own pause; selecting a destination hands off to the existing screen and its pause.
Dialogue Continue and fishing question buttons are the existing implementations.

PC: WASD, run, E interaction, R equipment, I inventory and M map remain on the existing
input paths. The pre-existing commented-out P opening shortcut in main.gd was preserved;
Quests opens from the menu/tracker, and P/Escape can close a HUD-owned quest board.

## Inspector configuration
Select GameplayHUD in the existing main scene. Touch Controls Mode is Auto by default:
use Always for a PC touch preview, or Never to hide the joystick. Radius, dead zone,
sensitivity, minimap diameter, edge padding, and HUD Scale are exposed. Layout caps
control dimensions on short screens. Radius is in logical UI units.
On mobile, display DPI supplies a density scale; the available viewport constrains
it to fit. Android/iOS safe-area coordinates are converted into viewport coordinates.
Positions snap to pixels; existing nearest-filter pixel-art rendering is retained.
No stretch/base-resolution or Android orientation settings were changed.

## Validation
- Installed UI/UX Pro Max local lookup: touch spacing, target sizes, gesture conflicts.
- Godot MCP verified the AquaQuest project path and Godot 4.5.1; inspected live scene
  tree and before/after screenshots. Simulated touch moved the real player at its
  existing 120 walk speed. Real contextual touch opened the teacher dialogue; HUD hid.
- 14 focused GUT tests: equipment, points, DDA-derived quest counts, all menu routes,
  pause ownership, keyboard input, independent touch indices, dead zone, dialogue,
  question buttons >=48 logical units, cleanup after player removal, and density scale.
- Layout checks: 1152x648 (actual native viewport), 1280x720, 1600x720, 1920x1080,
  1200x760, 720x360, and a portrait fallback. Additional 3x density simulation at 1920x1080.
- Desktop PNG captures: all four requested landscape sizes, 720x360, menu, and a
  simulated high-density phone. Capture process exits without GDScript errors.
- Full suite has three existing Region 1 failures in test/unit/test_region1_layout.gd:
  line 106 expects the old merchant position; line 170 expects removed outer guards;
  lines 189-190 expect VillageEnvironment, which is absent in the current scene.
  Region 1 and these tests were not modified for this HUD task.

## Remaining manual checks
No Android device/export was tested. Check physical touch comfort, notch/gesture safe
areas, device DPI, app interruption/resume, and emulated-mouse behavior on actual Android.
The high-density capture is a desktop simulation, not Android verification.
Existing house scenes also produce resource UID fallback warnings in desktop captures.
Editor history contained missing house.gd errors, but current saved house scenes no
longer reference that script; those historical editor errors were not treated as new HUD errors.

## Files
Modified: Scripts/UI/GameplayHUD.gd, Scripts/Systems/Player/PlayerInputComponent.gd,
Scripts/Systems/Interaction/InteractionComponent.gd, test/unit/test_gameplay_hud.gd.
Added: Scripts/UI/VirtualJoystick.gd, Scripts/UI/HUDTouchButton.gd, this document,
and Godot-generated UID metadata where present. Existing UI icons and theme are reused.
