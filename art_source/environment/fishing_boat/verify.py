"""Validate exported boat art and metadata. Requires the already-installed Pillow."""
import json
from pathlib import Path
from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "generated_assets/environment/fishing_boat"
HERE = Path(__file__).resolve().parent
VIEWS = ["top", "three_quarter", "side", "front"]
LEVELS = ["basic", "equipped", "upgraded"]
reference = json.loads((HERE / "palette_reference.json").read_text())
allowed = {tuple(bytes.fromhex(entry["hex"][1:])) for entry in reference["palette"].values()}


def rgba(path):
    with Image.open(path) as source:
        assert source.format == "PNG", path
        return source.convert("RGBA")


def pixel_checks(image):
    assert {p[3] for p in image.get_flattened_data()} == {0, 255}, "Alpha is not binary"
    assert {p[:3] for p in image.get_flattened_data() if p[3]} <= allowed, "Palette drift"


sprites = {}
for view in VIEWS:
    for level in LEVELS:
        name = f"boat_{level}_{view}"
        image = rgba(OUT / "sprites" / f"{name}.png")
        assert image.size == (128, 128), name
        pixel_checks(image)
        box = image.getbbox()
        assert box and box[0] >= 4 and box[1] >= 4 and box[2] <= 124 and box[3] <= 124, name
        sprites[name] = image
    alpha = sprites[f"boat_basic_{view}"].getchannel("A").tobytes()
    assert all(sprites[f"boat_{level}_{view}"].getchannel("A").tobytes() == alpha for level in LEVELS)
    assert len({sprites[f"boat_{level}_{view}"].tobytes() for level in LEVELS}) == 3, "Loadouts must differ"


def verify_sheet(name, expected_names, size):
    meta = json.loads((OUT / f"{name}.json").read_text())
    sheet = rgba(OUT / f"{name}.png")
    assert sheet.size == size
    pixel_checks(sheet)
    assert meta["meta"]["image"] == f"{name}.png"
    assert meta["meta"]["size"] == {"w": size[0], "h": size[1]}
    assert list(meta["frames"]) == expected_names
    frames = {}
    for index, (key, entry) in enumerate(meta["frames"].items()):
        x, y = (index % 4) * 128, (index // 4) * 128
        assert entry["frame"] == {"x": x, "y": y, "w": 128, "h": 128}, key
        assert not entry["rotated"] and not entry["trimmed"]
        assert entry["sourceSize"] == {"w": 128, "h": 128}
        assert entry["spriteSourceSize"] == {"x": 0, "y": 0, "w": 128, "h": 128}
        frames[key] = sheet.crop((x, y, x + 128, y + 128))
        if key in sprites:
            assert frames[key].tobytes() == sprites[key].tobytes(), key
    return meta, frames


verify_sheet("fishing_boat_views", [f"boat_basic_{view}" for view in VIEWS], (512, 128))
verify_sheet("fishing_boat_variations", [f"boat_{level}_{view}" for level in LEVELS for view in VIEWS], (512, 384))
meta, frames = verify_sheet("fishing_boat_animation", [f"boat_idle_{level}_{i}" for level in LEVELS for i in range(4)], (512, 384))
assert meta["meta"]["frameTags"] == [
    {"name": f"boat_idle_{level}", "from": row * 4, "to": row * 4 + 3, "direction": "forward"}
    for row, level in enumerate(LEVELS)
]
for level in LEVELS:
    static = sprites[f"boat_{level}_three_quarter"]
    strip = rgba(OUT / "anims" / f"boat_idle_{level}.png")
    strip_meta = json.loads((OUT / "anims" / f"boat_idle_{level}.json").read_text())
    assert strip.size == (512, 128)
    assert strip_meta["meta"]["image"] == f"boat_idle_{level}.png"
    assert strip_meta["meta"]["size"] == {"w": 512, "h": 128}
    for index, bob in enumerate([0, 1, 2, 1]):
        key = f"boat_idle_{level}_{index}"
        frame = frames[key]
        assert meta["frames"][key]["duration"] == 250
        assert strip_meta["frames"][key]["duration"] == 250
        assert strip_meta["frames"][key]["frame"] == {"x": index * 128, "y": 0, "w": 128, "h": 128}
        assert strip.crop((index * 128, 0, (index + 1) * 128, 128)).tobytes() == frame.tobytes()
        unbobbed = Image.new("RGBA", (128, 128))
        unbobbed.paste(frame, (0, -bob))
        # Every contour pixel must survive an exact integer translation.
        assert unbobbed.getchannel("A").tobytes() == static.getchannel("A").tobytes(), key
        differences = ImageChops.difference(unbobbed, static).convert("RGB")
        changed = sum(pixel != (0, 0, 0) for pixel in differences.get_flattened_data())
        assert changed <= 1, f"Hull deformation: {key} ({changed} changed pixels after alignment)"
    with Image.open(OUT / "anims" / f"boat_idle_{level}.gif") as gif:
        assert gif.n_frames == 4
        for index in range(4):
            gif.seek(index)
            assert gif.info["duration"] == 250

for name in ["fishing_boat_views", "fishing_boat_variations", "fishing_boat_animation"]:
    with Image.open(OUT / "_preview" / f"{name}.png") as preview:
        preview.verify()
with Image.open(OUT / "scenes/preview.png") as preview:
    assert preview.size == (512, 472)

print("PASS: 12 sprites, exact per-view silhouette across upgrades, palette/binary alpha, safe cell margins")
print("PASS: 3 sheets / 28 frame rectangles, static pixels, animation tags, strips and 250ms GIF frames")
print("PASS: all hulls identical after integer bob alignment; at most one moving equipment-tie pixel")
