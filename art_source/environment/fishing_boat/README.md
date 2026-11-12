# AquaQuest fishing bangka

An open wooden Filipino fishing boat with two bamboo outriggers. Created with the installed claude-pxl tool; no existing game assets, scenes, or gameplay scripts were replaced.

## Reference and style decisions

The audit preceded the artwork. See `palette_reference.json` for exact source paths, sampled colors, and observations, and `reference_board.png` for enlarged existing dock, building, shoreline, and character samples.

- Reuses `art_source/palettes/aquaquest.px.js`, based on `Resources/UI/ui_palette.json`.
- Adds only `#a96c3f` from existing building `Props.png` and `#a06131` from existing `Furniture.png` for environmental wood highlights. All final colors are checked against the documented palette.
- Uses one-pixel dark contours, hard material bands, upper/left highlights, and darker lower/right hull faces. Plank seams, joints, and lashings provide purposeful detail; no randomized grain, gradients, smoothing, or exterior cast shadow.
- Existing environment assets have one-pixel features and default 16px tile cells. The hull occupies roughly 5–6 tiles in length; all sprites use a **128x128 cell** with room for outriggers and transparent spacing. The cell is padding, not an instruction to stretch the sprite.
- The native-pixel `comparison_preview.png` places the three boat versions beside the original dock, character, and water textures for review. It is an opaque comparison image, not a game texture.

## Design and layout

Each perspective has one shared `_hull_*` part. The three loadouts stamp equipment over that same part, clipped inside its existing silhouette. Top view points up; three-quarter and side views point right; front view looks at the bow. The opposite outrigger is naturally occluded in side view.

Basic has seats, paddle details, and rope. Equipped adds a stowed fishing net. Upgraded adds a fish box, basket, and small wooden reinforcement straps while retaining the same outline. There are no sails, cabin, weapons, or decorative flags.

Exports live in `generated_assets/environment/fishing_boat/`:

| File | Size | Layout |
| --- | --- | --- |
| `fishing_boat_views.png` | 512x128 | Four basic views: top, three-quarter, side, front |
| `fishing_boat_variations.png` | 512x384 | Same four columns; rows basic, equipped, upgraded |
| `fishing_boat_animation.png` | 512x384 | Four idle frames per row; rows basic, equipped, upgraded |

Every sheet has a matching `.json` in TexturePacker hash format, with named 128x128 frame rectangles. No padding is inserted between cells; the artwork's internal transparent margins give clear separation. Do not trim individual sprites if using grid-based frames.

`sprites/` holds all 12 individual transparent views. `anims/` contains three 512x128 strips, matching JSON, and GIFs. Each idle loop is four frames at **4 FPS**, 250ms per frame, 1000ms total. Whole-boat offsets are `[0,1,2,1]` pixels vertically; a net tie moves one pixel on equipped/upgraded boats. Hulls are never scaled, rotated, or deformed.

`scenes/preview.png` is the labeled review board, and `_preview/` holds enlarged checkerboard/grid inspections. These previews intentionally have backgrounds and must not be used as game textures. `.gdignore` files keep the review scene/inspection folders out of Godot imports.

## Rebuild and preview

From the AquaQuest root:

```powershell
node tools/claude-pxl/bin/pxl.js build art_source/environment/fishing_boat/fishing_boat.px.js --out generated_assets/environment/fishing_boat --scale 3
python art_source/environment/fishing_boat/verify.py
node tools/claude-pxl/bin/pxl.js serve art_source/environment/fishing_boat/fishing_boat.px.js --no-out --port 4322
```

The live viewer is left running at [http://127.0.0.1:4322/](http://127.0.0.1:4322/). It watches the source and included palette. `--no-out` keeps previewing from rewriting finished exports; run `build` to update them. The earlier fishing-rod viewer on port 4321 is left alone. Stop a viewer launched in your terminal with Ctrl+C; select another port if the desired port is occupied.

The source uses the verified Canvas `clip(region, callback)` method inside drawing functions (`tools/claude-pxl/src/core/canvas.ts`). This differs from the declarative DSL `clip(region, ...items)` signature in the reference.

## Godot 4.5.1 import

1. Import the sheet PNGs normally. Use lossless compression, disable mipmaps for these sprites, and retain Nearest filtering (already the project default). Display at native scale or whole-number multiples.
2. For a static `Sprite2D`, assign `fishing_boat_variations.png`, set `hframes=4`, `vframes=3`, and choose `frame = row*4 + column`. Use `fishing_boat_views.png` with `hframes=4`, `vframes=1` for just the basic views.
3. For idle animation, create a `SpriteFrames` resource and use **Add frames from sprite sheet** with `fishing_boat_animation.png`, a 4-column/3-row grid. Add each row to its own looping animation at 4 FPS. The JSON frame tags identify the same three rows.
4. For individually named views, use the separate PNGs or create an `AtlasTexture` with the JSON's `frame` rectangle. TexturePacker JSON does not automatically create Godot animations; no importer/plugin is needed for manual grid import.

All frames share the same 128x128 canvas and center `(64,64)` so pivots remain stable. Center the sprite normally and avoid automatic cropping. Collision, occupancy, boat movement, and shoreline placement remain separate gameplay work and were not added.

## Verification

Automated checks passed for all 12 sprite PNGs, the three sheets, all 28 frame rectangles, three animation strips/GIFs, the palette, binary alpha, transparent cell margins, and exact static frame pixels. Each view's alpha silhouette is byte-identical across the three upgrades. Undoing each animation's integer bob offset gives the identical silhouette and identical hull pixels, allowing at most the one moving tie pixel.

A separate Godot **4.5.1 headless** check decoded all three transparent sheets, created 28 native `AtlasTexture` regions of 128x128, and matched static frame crops to their PNGs. The live browser viewer loaded without art errors. These are automated/visual asset checks, not manual gameplay testing.

Godot MCP was unavailable because another client owned its editor connection. Manual scene placement, physical Android testing, and player/boat interactions remain untested. Existing warnings about undefined future Codex regions appeared in the headless run and are unrelated to this artwork.
