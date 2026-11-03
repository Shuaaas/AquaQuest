# Coastal atlas artwork

`coastal_islands.png` is an original AI-generated illustration created with the
built-in image-generation tool for this approved AquaQuest world-map redesign.
The selected output was copied into this project; the original generated output
remains in the Codex generated-images folder. No external executable or dependency
was downloaded. This regional illustration is not exact playable level geometry.

1536x1024 RGBA; Godot AtlasTexture cells are 512x512:
- Top left: Region 1 coastal village.
- Top middle: Region 2 wetland.
- Top right: Region 3 processing/curing motif.
- Bottom left: Region 4 storehouse/preservation motif.
- Bottom middle: Region 5 archipelago.
- Bottom right: empty.

All labels, route dots, locks, current-region marker, selected outline and information
are native/runtime UI. No progress state or readable label is baked into the PNG.
`island_state.gdshader` clips the illustration's low-alpha backdrop and applies live
lock/unavailable desaturation plus a selected coastline outline. Each island owns
its material instance. The shader does not read or write gameplay state.

## Final generation prompt (built-in image_gen)

Repack these SAME five coastal island illustrations into a production GAME SPRITE
ATLAS. A landscape 3:2 transparent PNG with an invisible EXACT 3-column by 2-row equal
square cell grid, ideally 1536x1024 pixels with each cell512x512. No drawn grid, no
backgrounds, no numbers, no text. One completely isolated island per cell with genuine
alpha=0 around it. Maintain pixel-art island quality and colors from source. Essential
strict order: top LEFT cell the green fishing village (red/blue roof houses, docks,
littleboat); top CENTER cell wetland river-channel island; top RIGHT cell processing-yard
island with wooden racks/buildings/docks; bottom LEFT cell rocky storehouse island;
bottom CENTER cell tropical palm archipelago; bottom RIGHT cell completely EMPTY
transparent. Center each entire island within its own cell and fit all pixels inside
the central 82 percent of that square, with at least9 percent FULLY TRANSPARENT padding
on all four edges of EVERY cell. Do not overlap cells, crop docks or protrude past
margins. Top-left island center exactly(16.667% canvas width,25% canvas height);
top-middle(50%,25%); top-right(83.333%,25%); bottom-left(16.667%,75%);
bottom-middle(50%,75%). Each island has comparable overall scale within its cell, with
wide irregular coastlines and shallow foam fringe only. No water outside immediate
coastal fringe, no shadows outside coast, no fog, no clouds, no locks, no UI, no labels,
no compass, no flags or arrows, no connections. This PNG will be cut by Godot
AtlasTexture equal-cell rectangles, so 3x2 equal-square alignment is critical. Preserve
charming detailed coastal pixel-art aesthetic, olive foliage, sandy shores and warm
wood landmarks.

Supporting input: the clean five-island art derived from the approved concept, not
Potion Permit artwork. The generation requested transparency. Actual alpha and cell
alignment were inspected; the runtime shader trims low-alpha colored glow. Intermediate
concept/generated images are not referenced by the project.
