"""Verify the PXL integration fixture; run from any working directory."""
import json
from pathlib import Path
import re

from PIL import Image

root = Path(__file__).resolve().parents[1]
output = root / "generated_assets"
palette = json.loads((root / "Resources/UI/ui_palette.json").read_text())
allowed = {tuple(bytes.fromhex(color[1:])) for color in palette.values()}
pxl_palette = (root / "art_source/palettes/aquaquest.px.js").read_text()
assert set(re.findall(r'"(#[0-9a-f]{6})"', pxl_palette)) == set(palette.values())

names = ["test_fishing_rod", "test_fishing_rod_mirrored"]
sprites = {}
for name in names:
    path = output / "sprites" / f"{name}.png"
    with Image.open(path) as source:
        assert source.format == "PNG", path
        # PXL uses indexed PNG with tRNS transparency when the palette is small.
        assert source.mode == "RGBA" or "transparency" in source.info, path
        image = source.convert("RGBA")
    assert image.size == (32, 32), path
    pixels = [image.getpixel((x, y)) for y in range(32) for x in range(32)]
    assert {pixel[3] for pixel in pixels} == {0, 255}, "Partial alpha / missing transparency"
    opaque = [pixel for pixel in pixels if pixel[3]]
    assert 80 <= len(opaque) < 512, "Unexpected silhouette / background"
    assert {pixel[:3] for pixel in opaque} <= allowed, "Colors outside AquaQuest palette"
    assert all(image.getpixel((x, y))[3] == 0
               for x in range(32) for y in range(32)
               if x in (0, 31) or y in (0, 31)), "Silhouette clips canvas edge"
    sprites[name] = image

assert sprites[names[1]].tobytes() == sprites[names[0]].transpose(Image.Transpose.FLIP_LEFT_RIGHT).tobytes()
metadata = json.loads((output / "fishing_rods_test.json").read_text())
assert set(metadata["frames"]) == set(names)
assert metadata["meta"]["image"] == "fishing_rods_test.png"
assert metadata["meta"]["size"] == {"w": 64, "h": 32}
assert metadata["meta"]["format"] == "RGBA8888"
with Image.open(output / metadata["meta"]["image"]) as sheet:
    assert sheet.size == (64, 32)
    sheet = sheet.convert("RGBA")
    for index, name in enumerate(names):
        entry = metadata["frames"][name]
        assert entry["frame"] == {"x": index * 32, "y": 0, "w": 32, "h": 32}
        assert not entry["rotated"] and not entry["trimmed"]
        assert entry["sourceSize"] == {"w": 32, "h": 32}
        assert entry["spriteSourceSize"] == {"x": 0, "y": 0, "w": 32, "h": 32}
        crop = sheet.crop((index * 32, 0, (index + 1) * 32, 32))
        assert crop.tobytes() == sprites[name].tobytes(), "Sheet does not match JSON/sprite"

for name, dimensions in [(names[0], (512, 512)), (names[1], (512, 512)),
                         ("fishing_rods_test", (768, 384))]:
    with Image.open(output / "_preview" / f"{name}.png") as preview:
        assert preview.size == dimensions
        assert preview.convert("RGBA").getextrema()[3] == (255, 255)

print("PASS: palette source, two transparent 32x32 sprites, binary alpha, silhouette margins,")
print("      64x32 sheet, both JSON frame regions, exact sprite pixels, and three previews")
