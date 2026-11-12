---
name: pxl-pixel-art
description: Create or edit AquaQuest pixel-art sprites, fishing items, fish, tiles, and sprite sheets using the local claude-pxl CLI. Use for PXL or claude-pxl asset requests and pixel-art generation for this project.
---

# AquaQuest PXL workflow

Run commands from the AquaQuest project root. This project uses the upstream tool at `tools/claude-pxl`, not Claude Code's skill directory.

Before writing artwork, read the complete [upstream skill](../../../tools/claude-pxl/SKILL.md) and [API reference](../../../tools/claude-pxl/reference.md). Their `PXL` command means `node tools/claude-pxl/bin/pxl.js` here. Consult [lighting.md](../../../tools/claude-pxl/lighting.md) only for lighting work.

If the checkout is missing, follow [CLAUDE_PXL_SETUP.md](../../../CLAUDE_PXL_SETUP.md) to restore the recorded upstream commit. Node >=22.18 is required; no npm install is needed.

- Keep editable `.px.js` files in the matching `art_source/` subfolder, outside the upstream checkout.
- Include `../palettes/aquaquest.px.js` from category source files. Its colors come from `Resources/UI/ui_palette.json`; compare that source before changing the reusable palette. This is the existing UI palette, not a claim that every character sheet uses it.
- Use 32x32 for inventory icons unless the request specifies otherwise. Use transparent backgrounds, integer coordinates, crisp pixel edges, and consistent outlines/shading. `outline` grows the canvas by two pixels: start at 30x30 for a final 32x32 icon. Avoid `crop` when fixed dimensions matter.
- Keep all frames of an animation the same size. Preserve existing player proportions and frame dimensions; never replace existing assets or gameplay scripts without the user's approval.
- Build using `--out generated_assets`, preferably `--only` with the requested sprite and sheet names. PXL writes sprites under `sprites/`, sheet PNG/JSON pairs at the output root, and checkerboard inspection images under `_preview/`. Previews are not transparent game assets.
- Inspect the generated preview and actual PNG. Verify dimensions, alpha, palette, and JSON frame rectangles against the sheet pixels before calling artwork finished. Use the existing [verification example](../../../art_source/verify_fishing_rod.py) as a reference for this test's invariants; adapt checks for new assets rather than claiming it validates every future file.
- Give new assets unique names. Rebuilding the same requested PXL source may update its own generated outputs; do not overwrite unrelated outputs.
- Start `serve` for a live preview when requested, or when handing off a finished asset. Use a free loopback port and provide its URL. Record whether the preview server is still running.

Example:

```powershell
node tools/claude-pxl/bin/pxl.js build art_source/fishing_rods/test_fishing_rod.px.js --out generated_assets
node tools/claude-pxl/bin/pxl.js serve art_source/fishing_rods/test_fishing_rod.px.js --out generated_assets --port 4321
```

Supply the finished PNG, sheet/metadata paths, preview link, and verification results. Generated art stays staged in `generated_assets`; wiring it into inventory or replacing game art is a separate task.
