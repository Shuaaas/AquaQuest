# claude-pxl for AquaQuest

Installed and checked on 2026-11-05. This is a local pixel-art CLI and Codex skill, not an MCP server. No account, API key, remote generation service, or credits are needed.

## Installation

- Project: `C:\Users\joshu\OneDrive\Documents\aqua-questt`.
- Requirements: Node.js >=22.18 and Git. Installed versions checked: Node 26.13.0, Git 2.49.0.windows.1.
- Official checkout: `tools/claude-pxl`, commit `21fee41f7ecce00bc868d7567f24ffd0f3acc8fa` (MIT).
- No `npm install`, build step, runtime packages, or development dependencies were installed. The CLI runs the clone's TypeScript sources directly.
- The checkout is ignored by the AquaQuest Git repository, preventing an accidental nested repository/gitlink. To restore it on another machine, from the project root:

```powershell
git clone https://github.com/crsolver/claude-pxl.git tools/claude-pxl
git -C tools/claude-pxl checkout 21fee41f7ecce00bc868d7567f24ffd0f3acc8fa
node tools/claude-pxl/bin/pxl.js --help
```

Do not clone over an existing checkout. Check local modifications before updating upstream.

## Codex skill

The project skill is `.agents/skills/pxl-pixel-art/SKILL.md`. Codex discovers project skills under `.agents/skills`; `.claude/skills` is not used. The skill points to the complete upstream `SKILL.md`, `reference.md`, and optional `lighting.md` in the checkout and supplies AquaQuest paths and art constraints.

It will be available on the next turn. If it does not appear, restart Codex or explicitly mention `$pxl-pixel-art` and the skill path. Existing agent instructions, unrelated skills, and MCP settings were not changed.

Example request:

> Create an Epic-tier fishing rod for AquaQuest using claude-pxl. Follow the established AquaQuest palette and generate a transparent 32x32 PNG inventory icon. Include a browser preview and verify the output.

## Sources and outputs

`art_source/` contains `palettes/`, `characters/`, `fish/`, `fishing_rods/`, `items/`, `environment/`, and `animations/`. The reusable `palettes/aquaquest.px.js` maps every color from `Resources/UI/ui_palette.json` to a one-character PXL key. This is the established UI palette; existing character artwork may use additional colors.

Include that palette from category files with `include("../palettes/aquaquest.px.js")`. Use integer coordinates, transparent backgrounds, consistent dimensions, outlines, and shading. PXL's `outline` adds one pixel on each side: the test uses 30x30 internally for a final 32x32 icon. Keep generated art outside the upstream checkout.

Use the CLI's native output layout rather than moving its files after every rebuild:

```text
generated_assets/
  sprites/test_fishing_rod.png
  sprites/test_fishing_rod_mirrored.png
  fishing_rods_test.png           # 64x32, two adjacent 32x32 cells
  fishing_rods_test.json          # sheet metadata beside its PNG
  _preview/                      # opaque checkerboard/grid inspection images
```

Keeping the JSON beside its PNG preserves its relative image reference. `tools/`, `art_source/`, and `_preview/` have `.gdignore` files; Godot can still import the finished PNGs outside those folders.

## CLI and asset workflow

Run from the project root:

```powershell
node tools/claude-pxl/bin/pxl.js build art_source/fishing_rods/test_fishing_rod.px.js --out generated_assets
node tools/claude-pxl/bin/pxl.js list art_source/fishing_rods/test_fishing_rod.px.js
node tools/claude-pxl/bin/pxl.js ascii art_source/fishing_rods/test_fishing_rod.px.js test_fishing_rod
node tools/claude-pxl/bin/pxl.js serve art_source/fishing_rods/test_fishing_rod.px.js --out generated_assets --port 4321
```

`build` supports `--only name1,name2,sheet_name` for targeted iterations. Write source, build, inspect `_preview/` and the actual transparent PNG, patch the source, and rebuild. Never use preview images as game textures. Give new assets unique names and do not overwrite existing AquaQuest assets.

The setup left a local viewer running at [http://127.0.0.1:4321/](http://127.0.0.1:4321/), opened in the browser. It watches the source and included palette; it does not restart automatically after reboot. Stop a foreground viewer with Ctrl+C. If port 4321 is occupied, use a free port with `--port` instead of terminating an unrelated process.

## Verification and Godot

The test verifier uses the already-installed Python/Pillow (Pillow 12.2.0 was checked); this is optional QA tooling, not a dependency of PXL:

```powershell
python art_source/verify_fishing_rod.py
```

Verified: exact palette values, two transparent 32x32 PNGs, only fully transparent/opaque pixels, no clipped borders, mirrored pixels, 64x32 sheet, JSON coordinates/source sizes, exact frame-to-PNG pixel matches, three inspection previews, byte-identical repeated builds, and browser auto-refresh after saving the source. The compact PNGs use indexed colors with PNG transparency, which is valid and decoded correctly by Godot.

A separate Godot 4.5.1 headless check loaded both PNGs, confirmed alpha and dimensions, created `ImageTexture`s, and matched the sheet regions to the source images. No existing gameplay or art was replaced.

Use `res://generated_assets/sprites/test_fishing_rod.png` for an inventory texture. Keep lossless import, mipmaps off for the icon, and nearest texture filtering (already the project default). The sheet can be used with `Sprite2D.hframes = 2`, `vframes = 1`, or `AtlasTexture` rectangles from JSON. Godot does **not** automatically turn TexturePacker JSON into animations without an importer; no importer/plugin was added.

Live Godot MCP testing was blocked by another connected client. Manual in-game and physical Android checks remain unperformed. Existing CodexManager warnings for undefined future regions appeared in the headless run and are unrelated to these assets.

## Troubleshooting

- Node/type stripping errors: verify `node --version` is >=22.18 and run from the clone, not a copied `node_modules` directory.
- Missing tool: restore the recorded checkout; do not install a look-alike npm package.
- API errors: read upstream `reference.md`; use reported file/line/op details and `ascii` to locate mistakes.
- Unexpected icon dimensions: account for automatic outline growth and avoid `crop` on fixed-size frames.
- Palette drift: compare the reusable PXL palette against `Resources/UI/ui_palette.json` before generating.
- Missing preview: rerun `serve`, check its displayed port and errors, then open its loopback URL.

Sources: [official repository/README](https://github.com/crsolver/claude-pxl), [upstream skill](https://github.com/crsolver/claude-pxl/blob/main/SKILL.md), [API reference](https://github.com/crsolver/claude-pxl/blob/main/reference.md), [Codex skill discovery](https://developers.openai.com/codex/skills).
