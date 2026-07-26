"""Generate native-resolution pixel-art terrain and modular Vierth town props.

The ground is authored at one source pixel per Godot world unit. Nothing in
this pipeline scales a small texture over a larger area: repeating patterns are
painted directly into the final 1600x1120 image and imported with nearest
filtering. The atlas remains useful for later hand-authored TileMapLayer work.
"""

from __future__ import annotations

import argparse
import json
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw


TILE_SIZE = 32
ATLAS_COLUMNS = 4
ATLAS_ROWS = 2
COLORS = {
    "grass": (73, 89, 52, 255),
    "grass_dark": (54, 70, 44, 255),
    "grass_light": (101, 111, 60, 255),
    "cobble": (115, 105, 90, 255),
    "cobble_dark": (77, 73, 69, 255),
    "cobble_light": (151, 137, 111, 255),
    "water": (42, 96, 111, 255),
    "water_dark": (27, 69, 84, 255),
    "water_light": (83, 144, 145, 255),
    "soil": (105, 79, 47, 255),
    "stone": (105, 103, 97, 255),
    "stone_dark": (61, 63, 61, 255),
    "brass": (187, 138, 54, 255),
    "wood": (91, 55, 34, 255),
    "wood_dark": (49, 34, 29, 255),
    "roof": (91, 48, 43, 255),
    "roof_dark": (51, 35, 39, 255),
    "plaster": (191, 170, 124, 255),
}


def _noise_dots(
    image: Image.Image,
    bounds: tuple[int, int, int, int],
    rng: random.Random,
    colors: list[tuple[int, int, int, int]],
    count: int,
) -> None:
    draw = ImageDraw.Draw(image)
    left, top, right, bottom = bounds
    for _ in range(count):
        x = rng.randrange(left, max(left + 1, right))
        y = rng.randrange(top, max(top + 1, bottom))
        color = rng.choice(colors)
        size = 1 if rng.random() < 0.82 else 2
        draw.rectangle((x, y, x + size - 1, y + size - 1), fill=color)


def _inside_rect(x: int, y: int, center: tuple[float, float], half: tuple[float, float]) -> bool:
    return abs(x - center[0]) <= half[0] and abs(y - center[1]) <= half[1]


def build_ground(blueprint: dict, output: Path) -> Image.Image:
    width = int(blueprint["map_size"][0]) * TILE_SIZE
    height = int(blueprint["map_size"][1]) * TILE_SIZE
    terrain = blueprint["terrain"]
    rng = random.Random(int(blueprint["seed"]))
    image = Image.new("RGBA", (width, height), COLORS["grass"])
    pixels = image.load()

    river_x = float(terrain["river"]["center_x"]) * TILE_SIZE
    river_half = float(terrain["river"]["half_width"]) * TILE_SIZE
    street_x = float(terrain["main_street"]["center_x"]) * TILE_SIZE
    street_half = float(terrain["main_street"]["half_width"]) * TILE_SIZE
    cross_y = float(terrain["cross_street"]["center_y"]) * TILE_SIZE
    cross_half = float(terrain["cross_street"]["half_width"]) * TILE_SIZE
    square_center = tuple(float(v) * TILE_SIZE for v in terrain["town_square"]["center"])
    square_half = tuple(float(v) * TILE_SIZE for v in terrain["town_square"]["half_size"])
    bridge_y = float(terrain["bridge_y"]) * TILE_SIZE

    for y in range(height):
        river_curve = math.sin(y * 0.008) * 11.0 + math.sin(y * 0.021) * 3.0
        for x in range(width):
            # River is evaluated first, then the stone bridge cuts across it.
            river_distance = abs(x - (river_x + river_curve))
            is_river = river_distance < river_half
            is_bank = river_half <= river_distance < river_half + 18
            is_bridge = (
                abs(y - bridge_y) < 48
                and river_distance < river_half + 26
            )
            wobble = math.sin(y * 0.013) * 7.0
            main_street = abs(x - (street_x + wobble)) < street_half
            cross_street = abs(y - cross_y) < cross_half and x < river_x + river_half
            square = _inside_rect(x, y, square_center, square_half)

            if is_bridge:
                base = COLORS["stone"]
                if (x // 14 + y // 9) % 3 == 0:
                    base = COLORS["cobble_light"]
            elif is_river:
                stripe = (x + y // 3) % 23
                base = (
                    COLORS["water_light"]
                    if stripe < 3
                    else COLORS["water"] if stripe < 17 else COLORS["water_dark"]
                )
            elif is_bank:
                base = COLORS["soil"] if (x + y) % 7 else COLORS["grass_dark"]
            elif square or main_street or cross_street:
                mortar = ((x // 14) + ((y // 8) & 1) * 7) % 14
                if y % 8 == 0 or mortar in (0, 1):
                    base = COLORS["cobble_dark"]
                else:
                    variation = (x * 13 + y * 7 + int(5 * math.sin(x))) % 17
                    base = COLORS["cobble_light"] if variation < 3 else COLORS["cobble"]
            else:
                variation = (x * 17 + y * 11) % 61
                if variation == 0:
                    base = COLORS["grass_light"]
                elif variation in (1, 2):
                    base = COLORS["grass_dark"]
                else:
                    base = COLORS["grass"]
            pixels[x, y] = base

    # Native-pixel accents break flat fills without changing texel density.
    _noise_dots(
        image,
        (0, 0, width, height),
        rng,
        [COLORS["grass_dark"], COLORS["grass_light"], (151, 91, 35, 255)],
        width * height // 240,
    )
    image.save(output)
    return image


def _new_prop(size: tuple[int, int]) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    return image, ImageDraw.Draw(image)


def build_house(
    size: tuple[int, int],
    roof: tuple[int, int, int, int],
    sign: bool = False,
    porch: bool = False,
) -> Image.Image:
    image, draw = _new_prop(size)
    width, height = size
    base_y = height - 12
    wall_top = int(height * 0.42)
    wall_left = 18
    wall_right = width - 18
    draw.rectangle((wall_left, wall_top, wall_right, base_y), fill=COLORS["plaster"])
    for y in range(wall_top + 8, base_y, 12):
        draw.line((wall_left, y, wall_right, y), fill=(153, 132, 94, 255), width=2)
    draw.polygon(
        (
            (8, wall_top + 8),
            (width // 2, 10),
            (width - 8, wall_top + 8),
            (width - 18, wall_top + 22),
            (18, wall_top + 22),
        ),
        fill=roof,
    )
    for x in range(18, width - 18, 12):
        draw.line((x, wall_top + 6, x + width // 3, 24), fill=COLORS["roof_dark"], width=2)
    door_w = 30
    draw.rectangle(
        (width // 2 - door_w // 2, base_y - 50, width // 2 + door_w // 2, base_y),
        fill=COLORS["wood_dark"],
    )
    for window_x in (width // 4, width * 3 // 4):
        draw.rectangle((window_x - 15, base_y - 52, window_x + 15, base_y - 26), fill=COLORS["wood_dark"])
        draw.rectangle((window_x - 11, base_y - 48, window_x + 11, base_y - 30), fill=(226, 172, 78, 255))
        draw.line((window_x, base_y - 48, window_x, base_y - 30), fill=COLORS["brass"], width=2)
    draw.rectangle((wall_left - 5, base_y, wall_right + 5, base_y + 8), fill=COLORS["stone_dark"])
    if porch:
        draw.rectangle((width // 2 - 60, base_y + 4, width // 2 + 60, base_y + 14), fill=COLORS["wood"])
        draw.rectangle((width // 2 - 58, base_y - 28, width // 2 - 52, base_y + 7), fill=COLORS["wood_dark"])
        draw.rectangle((width // 2 + 52, base_y - 28, width // 2 + 58, base_y + 7), fill=COLORS["wood_dark"])
    if sign:
        draw.line((width - 45, base_y - 76, width - 45, base_y - 42), fill=COLORS["wood_dark"], width=4)
        draw.ellipse((width - 59, base_y - 75, width - 31, base_y - 55), fill=COLORS["brass"], outline=COLORS["wood_dark"], width=2)
    return image


def build_tree() -> Image.Image:
    image, draw = _new_prop((112, 144))
    draw.rectangle((51, 88, 62, 135), fill=COLORS["wood_dark"])
    draw.rectangle((54, 84, 59, 135), fill=COLORS["wood"])
    clusters = [
        (56, 32, 34, (183, 75, 29, 255)),
        (34, 56, 30, (151, 59, 28, 255)),
        (78, 59, 31, (211, 105, 27, 255)),
        (54, 72, 37, (171, 66, 25, 255)),
    ]
    for cx, cy, radius, color in clusters:
        draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=color)
        draw.rectangle((cx - radius + 5, cy + radius - 7, cx + radius - 5, cy + radius), fill=(108, 50, 29, 255))
    return image


def build_well() -> Image.Image:
    image, draw = _new_prop((112, 112))
    draw.ellipse((16, 48, 96, 88), fill=COLORS["stone_dark"])
    draw.ellipse((20, 42, 92, 78), fill=COLORS["stone"], outline=COLORS["cobble_light"], width=4)
    draw.ellipse((31, 51, 81, 70), fill=(28, 54, 58, 255))
    draw.rectangle((25, 18, 31, 56), fill=COLORS["wood_dark"])
    draw.rectangle((81, 18, 87, 56), fill=COLORS["wood_dark"])
    draw.polygon(((17, 22), (56, 5), (95, 22), (86, 34), (25, 34)), fill=COLORS["roof"])
    return image


def build_stall(color_name: str) -> Image.Image:
    canopies = {
        "amber": (201, 137, 38, 255),
        "red": (154, 57, 45, 255),
        "green": (74, 111, 67, 255),
        "blue": (61, 93, 121, 255),
    }
    image, draw = _new_prop((128, 96))
    draw.rectangle((15, 55, 113, 77), fill=COLORS["wood"])
    draw.rectangle((20, 26, 26, 86), fill=COLORS["wood_dark"])
    draw.rectangle((102, 26, 108, 86), fill=COLORS["wood_dark"])
    draw.polygon(((8, 29), (22, 11), (106, 11), (120, 29)), fill=canopies[color_name])
    for x in range(22, 108, 18):
        draw.rectangle((x, 11, x + 8, 29), fill=(225, 184, 96, 255))
    for x in range(28, 100, 18):
        draw.ellipse((x, 58, x + 10, 68), fill=(132, 54 + x % 35, 31, 255))
    return image


def build_bridge() -> Image.Image:
    image, draw = _new_prop((260, 128))
    draw.rectangle((6, 25, 254, 104), fill=COLORS["stone_dark"])
    draw.rectangle((10, 30, 250, 98), fill=COLORS["stone"])
    for y in range(34, 98, 16):
        offset = 0 if (y // 16) % 2 else 14
        draw.line((10, y, 250, y), fill=COLORS["stone_dark"], width=2)
        for x in range(10 + offset, 250, 28):
            draw.line((x, y, x, min(98, y + 15)), fill=COLORS["stone_dark"], width=2)
    draw.rectangle((2, 17, 258, 27), fill=COLORS["cobble_light"])
    draw.rectangle((2, 100, 258, 110), fill=COLORS["cobble_light"])
    return image


def build_lamp() -> Image.Image:
    image, draw = _new_prop((48, 96))
    draw.rectangle((22, 28, 26, 88), fill=COLORS["stone_dark"])
    draw.rectangle((17, 82, 31, 91), fill=COLORS["stone_dark"])
    draw.polygon(((12, 31), (18, 17), (30, 17), (36, 31), (30, 45), (18, 45)), fill=COLORS["brass"])
    draw.rectangle((18, 23, 30, 37), fill=(252, 196, 89, 255))
    return image


def build_light_texture() -> Image.Image:
    image = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    pixels = image.load()
    for y in range(128):
        for x in range(128):
            distance = math.dist((x, y), (63.5, 63.5)) / 64.0
            alpha = max(0, min(150, int((1.0 - distance) ** 2 * 150)))
            pixels[x, y] = (255, 190, 87, alpha)
    return image


def build_atlas(ground: Image.Image, output: Path, metadata: Path) -> None:
    atlas = Image.new("RGBA", (ATLAS_COLUMNS * TILE_SIZE, ATLAS_ROWS * TILE_SIZE), (0, 0, 0, 0))
    samples = [
        ground.crop((64, 64, 96, 96)),
        ground.crop((128, 128, 160, 160)),
        ground.crop((790, 540, 822, 572)),
        ground.crop((710, 540, 742, 572)),
        ground.crop((1216, 352, 1248, 384)),
        ground.crop((1248, 352, 1280, 384)),
        ground.crop((1220, 530, 1252, 562)),
        ground.crop((1270, 530, 1302, 562)),
    ]
    names = ["grass", "grass_leaves", "cobble", "cobble_light", "river", "river_dark", "riverbank", "bridge"]
    for index, sample in enumerate(samples):
        atlas.paste(sample, ((index % ATLAS_COLUMNS) * TILE_SIZE, (index // ATLAS_COLUMNS) * TILE_SIZE))
    atlas.save(output)
    metadata.write_text(
        json.dumps(
            {
                "tile_size": TILE_SIZE,
                "pixels_per_world_unit": 1,
                "resampled": False,
                "tiles": [{"id": index, "name": name, "atlas": [index % 4, index // 4]} for index, name in enumerate(names)],
            },
            indent=2,
        ),
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--blueprint", type=Path, default=Path("data/levels/vierth_town_blueprint.json"))
    parser.add_argument("--tilesets", type=Path, default=Path("assets/tilesets"))
    parser.add_argument("--environment", type=Path, default=Path("assets/environment/town"))
    args = parser.parse_args()
    blueprint = json.loads(args.blueprint.read_text(encoding="utf-8"))
    args.tilesets.mkdir(parents=True, exist_ok=True)
    args.environment.mkdir(parents=True, exist_ok=True)

    ground = build_ground(blueprint, args.tilesets / "vierth_town_ground.png")
    build_atlas(
        ground,
        args.tilesets / "vierth_town_atlas.png",
        args.tilesets / "vierth_town_atlas.json",
    )
    props = {
        "bakery.png": build_house((256, 192), (166, 80, 43, 255), sign=True),
        "tavern.png": build_house((304, 208), (82, 52, 54, 255), sign=True, porch=True),
        "iven_house.png": build_house((224, 176), (67, 82, 69, 255)),
        "resident_house_a.png": build_house((208, 168), (105, 65, 47, 255)),
        "resident_house_b.png": build_house((208, 168), (83, 75, 62, 255)),
        "resident_house_c.png": build_house((208, 168), (96, 58, 64, 255)),
        "autumn_tree.png": build_tree(),
        "well.png": build_well(),
        "stall_amber.png": build_stall("amber"),
        "stall_red.png": build_stall("red"),
        "stall_green.png": build_stall("green"),
        "stall_blue.png": build_stall("blue"),
        "stone_bridge.png": build_bridge(),
        "street_lamp.png": build_lamp(),
        "town_light.png": build_light_texture(),
    }
    for filename, image in props.items():
        image.save(args.environment / filename)
    print(f"Built Vierth town ground: {ground.size[0]}x{ground.size[1]} at native 1:1 PPU")
    print(f"Built {len(props)} modular town props")


if __name__ == "__main__":
    main()
