# AquaQuest pixel UI style guide

## Reference and visual identity

The existing artwork in `Assets/Environment/` and `Assets/Tavern/Tavern.png` is the reference. Warm brown wood, near-black brown outlines, cream highlights, muted blue accents and olive greenery connect the UI to that artwork. Environmental sheets use compact pixel clusters, stepped silhouettes, a few discrete shade levels and hard shadows. Black padding around sprites is not a recommended panel fill.

The new UI frames are original SVG drawings in `Assets/UI/Pixel/`. No environmental image or cropped tile is used as a button, panel, border or icon. The illustrated world map now draws its own geometric tree symbols. The minimap continues to show the actual world through its existing viewport; that is map content, not a repurposed UI texture.

## Shared palette

| Role | Color | Use |
| --- | --- | --- |
| Ink | `#160f09` | Crisp outer outlines |
| Shadow | `#2f1c10` | Hard shadows and recessed controls |
| Panel | `#341f12` | Reading surfaces |
| Wood | `#7d4c28` | Button faces and framing |
| Edge | `#5a361e` | Dark bevels |
| Highlight | `#ba9e6e` | Top/left edges and headings |
| Text | `#ddccb8` | Body text |
| Bright | `#fffce6` | Strong emphasis and player marker |
| Focus | `#8ac6e0` | Keyboard focus and current selection |
| Selected | `#3b535e` | Selected controls and map sea |
| Moss | `#62791e` | Completed-region accent |
| Mini quest | `#7a5388` | Existing mini-quest marker distinction |

The machine-readable palette is `Resources/UI/ui_palette.json`. Preserve existing educational figures and live world artwork in their authored colors. The UI palette applies to UI chrome, not those source materials. Pair status colors with labels or symbols rather than relying on color alone.

## Pixel and layout rules

- Source artwork has thin native-pixel outlines. UI frames adapt that treatment to 2-pixel stepped edges, discrete light/mid/dark tones and 4-pixel hard shadows. Avoid gradients, soft shadows and rounded modern cards.
- Frames are 32-pixel source drawings used as nine-slice StyleBoxTextures. Keep corner slices intact; stretch the center instead of stretching the whole border.
- `PixelUIStyle.gd` applies nearest-neighbor filtering and Godot's bundled font with antialiasing and subpixel positioning disabled. No external font dependency is required. Avoid fractional scaling when placing new UI.
- Default body text is 18 pixels, section text 20, headings 22 and captions 16. Keep long questions and dialogue scrollable. Do not shrink educational text to force it into a fixed panel.
- Buttons have at least 48 logical pixels of height. Containers, wrapping and scroll areas accommodate narrow screens. Phone landscape dialogue uses a taller panel so choices remain accessible.
- Device DPI, physical touch size, safe areas, Android keyboard behavior and rendering on a physical Android device still require manual validation. Desktop viewport checks do not establish physical-device accessibility.

## Reusing the components

Use `Resources/UI/AquaQuestTheme.tres` on a Control root and add a child Node using `Scripts/UI/PixelUIStyle.gd`. The helper styles newly generated controls as well as existing children, without consulting quest, score, save or progression state. Use the `AquaHeading`, `AquaSection`, `AquaCaption`, `AquaInset` and `AquaHUD` theme variations for consistent hierarchy.

Prefer Container nodes to fixed positions for content. Keep existing signal connections, unique node names, scripts and data ownership when rearranging controls. For very dense navigation, use a scroll area or a separate layout rather than reducing text size.

## Applied screens and limits

The existing dialogue, inventory, fishing question, exam, shop, result toast, performance board, Codex, world map and minimap scenes use the shared skin. The existing quest log appears under a Quest Journal heading in the performance board. Fishing results retain their existing toast behavior.

`Scene/UI/PixelStyleGallery.tscn` can be opened and run separately in Godot to preview the components. Its Main Menu, Pause Menu, Settings and separate Quest Journal cards are visual examples only: those cards do not implement navigation, settings, saving or a new quest system. The gallery is not added to the game's startup scene.

## Validation

Godot 4.5.1 imported the new assets. Engine-rendered checks cover the existing screens at 1200×760, 390×844 and 720×360, plus the component gallery. These checks cover presentation and rendering; they do not replace clicking through every gameplay path.

The existing GUT suite covers gameplay regressions. Recommended manual follow-up: open each real screen through gameplay, test mouse/keyboard focus, scroll long dialogue and questions, switch Codex modules, buy/equip through existing handlers, close and reopen overlays, then repeat on an Android device. Confirm no touch target is obstructed by device edges. Keep gameplay and DDA rules unchanged during visual adjustments.
