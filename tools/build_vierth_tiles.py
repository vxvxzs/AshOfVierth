"""Build the Vierth Entrance ground, object sprites and compatibility atlas.

The generated source is a 4x4 sheet on a saturated magenta key. Ground is
rendered as one continuous 960x640 image, while large props remain independent
transparent sprites. Only small terrain samples are kept in the 32 px atlas.
"""

from __future__ import annotations

import argparse
import json
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


GRID_COLUMNS = 4
GRID_ROWS = 4
TILE_SIZE = 32
GROUND_PIXELS_PER_WORLD_UNIT = 1
TILE_NAMES = [
    "autumn_grass",
    "leaf_grass",
    "road_center",
    "road_leaves",
    "road_edge_north",
    "road_edge_south",
    "road_bend",
    "road_junction",
    "autumn_shrub",
    "autumn_tree",
    "mossy_rock",
    "tree_stump",
    "fence_horizontal",
    "fence_vertical",
    "fence_corner",
    "entrance_sign",
]
OBJECT_SPECS = {
    8: ("autumn_shrub.png", (64, 64), (62, 56)),
    9: ("autumn_tree.png", (96, 128), (92, 122)),
    10: ("mossy_rock.png", (80, 72), (74, 64)),
    11: ("tree_stump.png", (64, 64), (60, 56)),
    12: ("fence_horizontal.png", (96, 64), (92, 58)),
    13: ("fence_vertical.png", (64, 96), (48, 90)),
    14: ("fence_corner.png", (96, 80), (92, 74)),
    15: ("entrance_sign.png", (64, 96), (58, 90)),
}


def remove_magenta(image: Image.Image) -> Image.Image:
    """Create a hard alpha channel and remove magenta matte pixels completely."""
    rgba = image.convert("RGBA")
    cleaned = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    source_pixels = rgba.load()
    target_pixels = cleaned.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, _ = source_pixels[x, y]
            distance = math.sqrt(
                (red - 255) ** 2
                + green**2
                + (blue - 255) ** 2
            )
            is_key = (
                distance < 150
                or (
                    red > 165
                    and blue > 125
                    and green < 135
                    and min(red, blue) - green > 55
                )
                or (
                    red > 105
                    and blue > 80
                    and red > green * 1.35
                    and blue > green * 1.20
                )
            )
            if not is_key:
                target_pixels[x, y] = (red, green, blue, 255)
    return cleaned


def split_cells(source: Image.Image) -> list[Image.Image]:
    cells: list[Image.Image] = []
    for tile_id in range(GRID_COLUMNS * GRID_ROWS):
        column = tile_id % GRID_COLUMNS
        row = tile_id // GRID_COLUMNS
        left = round(column * source.width / GRID_COLUMNS)
        top = round(row * source.height / GRID_ROWS)
        right = round((column + 1) * source.width / GRID_COLUMNS)
        bottom = round((row + 1) * source.height / GRID_ROWS)
        cells.append(source.crop((left, top, right, bottom)))
    return cells


def crop_opaque_center(cell: Image.Image, fraction: float = 0.50) -> Image.Image:
    """Take only the uninterrupted center of a terrain patch."""
    width, height = cell.size
    crop_width = max(8, round(width * fraction))
    crop_height = max(8, round(height * fraction))
    left = (width - crop_width) // 2
    top = (height - crop_height) // 2
    crop = cell.crop((left, top, left + crop_width, top + crop_height))
    opaque = Image.new("RGBA", crop.size, (91, 78, 37, 255))
    opaque.alpha_composite(crop)
    return opaque


def make_natural_texture(
    cell: Image.Image,
    size: tuple[int, int],
    seed: int,
) -> Image.Image:
    """Tile native source pixels without ever resampling the ground texture."""
    # The AI source tiles have a keyed-magenta matte around their painted
    # patch. 38% is the largest uninterrupted center shared by both grass and
    # road samples, so no keyed fringe can leak into the repeated texture.
    source = crop_opaque_center(cell, 0.38)
    tile_width, tile_height = source.size
    mirror_tile = Image.new(
        "RGBA",
        (tile_width * 2, tile_height * 2),
        (0, 0, 0, 255),
    )
    mirror_tile.paste(source, (0, 0))
    mirror_tile.paste(
        source.transpose(Image.Transpose.FLIP_LEFT_RIGHT),
        (tile_width, 0),
    )
    mirror_tile.paste(
        source.transpose(Image.Transpose.FLIP_TOP_BOTTOM),
        (0, tile_height),
    )
    mirror_tile.paste(
        source.transpose(Image.Transpose.FLIP_LEFT_RIGHT).transpose(
            Image.Transpose.FLIP_TOP_BOTTOM
        ),
        (tile_width, tile_height),
    )

    result = Image.new("RGBA", size, (0, 0, 0, 255))
    for y in range(0, size[1], mirror_tile.height):
        for x in range(0, size[0], mirror_tile.width):
            result.paste(mirror_tile, (x, y))

    # Break the mirrored rhythm only through translation and mirroring.
    # Resizing even with nearest-neighbour changed the effective texel density
    # of individual patches and made the road look like a stretched mosaic.
    irregular = cell.crop(cell.getbbox()) if cell.getbbox() else cell
    rng = random.Random(seed)
    overlay_count = max(10, round(size[0] * size[1] / 52000))
    for _index in range(overlay_count):
        overlay = irregular.copy()
        if rng.random() < 0.5:
            overlay = overlay.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        if rng.random() < 0.5:
            overlay = overlay.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
        x = rng.randint(-overlay.width // 3, max(0, size[0] - overlay.width * 2 // 3))
        y = rng.randint(-overlay.height // 3, max(0, size[1] - overlay.height * 2 // 3))
        result.alpha_composite(overlay, (x, y))
    return result


def smooth_values(values: list[float]) -> list[float]:
    """Round harsh tile-to-tile road turns while preserving the route."""
    weights = (1.0, 2.0, 3.0, 4.0, 3.0, 2.0, 1.0)
    radius = len(weights) // 2
    smoothed: list[float] = []
    for index in range(len(values)):
        total = 0.0
        total_weight = 0.0
        for offset, weight in enumerate(weights):
            sample_index = max(
                0,
                min(len(values) - 1, index + offset - radius),
            )
            total += values[sample_index] * weight
            total_weight += weight
        smoothed.append(total / total_weight)
    return smoothed


def build_ground(
    cells: list[Image.Image],
    blueprint: dict,
    output_path: Path,
) -> None:
    map_width, map_height = blueprint["map_size"]
    tile_size = int(blueprint["tile_size"])
    output_size = (map_width * tile_size, map_height * tile_size)
    base_seed = int(blueprint.get("forest_seed", 417))
    grass = make_natural_texture(cells[0], output_size, base_seed)
    road_texture = make_natural_texture(cells[2], output_size, base_seed + 101)

    centers = smooth_values(
        [float(center) for center in blueprint["road_centers"]]
    )
    road_half_width = (float(blueprint["road_half_width"]) + 0.65) * tile_size
    left_edge: list[tuple[float, float]] = []
    right_edge: list[tuple[float, float]] = []
    for pixel_y in range(-32, output_size[1] + 33, 8):
        row_position = max(0.0, min(len(centers) - 1.0, pixel_y / tile_size))
        row_a = int(math.floor(row_position))
        row_b = min(len(centers) - 1, row_a + 1)
        interpolation = row_position - row_a
        center_tile = (
            float(centers[row_a]) * (1.0 - interpolation)
            + float(centers[row_b]) * interpolation
        )
        center_x = (center_tile + 0.5) * tile_size
        center_x += math.sin(pixel_y * 0.018) * 2.0
        width_variation = math.sin(pixel_y * 0.014 + 1.3) * 3.0
        half_width = road_half_width + width_variation
        left_edge.append((center_x - half_width, float(pixel_y)))
        right_edge.append((center_x + half_width, float(pixel_y)))

    road_polygon = left_edge + list(reversed(right_edge))
    sharp_mask = Image.new("L", output_size, 0)
    ImageDraw.Draw(sharp_mask).polygon(road_polygon, fill=255)
    # The road is a world-space pixel texture. A blurred alpha edge would remain
    # visibly soft even with nearest-neighbour filtering in Godot.
    road_mask = sharp_mask
    verge_mask = sharp_mask.filter(ImageFilter.MaxFilter(size=5))
    verge_texture = make_natural_texture(
        cells[1],
        output_size,
        base_seed + 303,
    )
    grass = Image.composite(verge_texture, grass, verge_mask)
    ground = Image.composite(road_texture, grass, road_mask)
    ground = ground.convert("RGB").convert("RGBA")
    if ground.size != output_size:
        raise RuntimeError(
            "Ground must remain 1:1 with world pixels: "
            f"expected {output_size}, got {ground.size}"
        )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    ground.save(output_path)


def fit_object(
    cell: Image.Image,
    canvas_size: tuple[int, int],
    target_size: tuple[int, int],
) -> Image.Image:
    bbox = cell.getbbox()
    result = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    if bbox is None:
        return result
    cropped = cell.crop(bbox)
    ratio = min(target_size[0] / cropped.width, target_size[1] / cropped.height)
    resized_size = (
        max(1, round(cropped.width * ratio)),
        max(1, round(cropped.height * ratio)),
    )
    cropped = cropped.resize(resized_size, Image.Resampling.NEAREST)
    result.alpha_composite(
        cropped,
        (
            (canvas_size[0] - resized_size[0]) // 2,
            canvas_size[1] - resized_size[1],
        ),
    )
    # Enforce binary alpha. No colored matte or semi-transparent square remains.
    pixels = result.load()
    for y in range(result.height):
        for x in range(result.width):
            red, green, blue, alpha = pixels[x, y]
            pixels[x, y] = (red, green, blue, 255 if alpha >= 128 else 0)
    return result


def build_objects(cells: list[Image.Image], output_directory: Path) -> None:
    output_directory.mkdir(parents=True, exist_ok=True)
    for tile_id, (filename, canvas_size, target_size) in OBJECT_SPECS.items():
        fit_object(cells[tile_id], canvas_size, target_size).save(
            output_directory / filename
        )


def build_compatibility_atlas(
    cells: list[Image.Image],
    atlas_path: Path,
    metadata_path: Path,
    ground_size: tuple[int, int],
) -> None:
    """Keep a small atlas for TileSet tooling, but do not use it for large props."""
    atlas = Image.new(
        "RGBA",
        (GRID_COLUMNS * TILE_SIZE, GRID_ROWS * TILE_SIZE),
        (0, 0, 0, 0),
    )
    for tile_id, cell in enumerate(cells):
        column = tile_id % GRID_COLUMNS
        row = tile_id // GRID_COLUMNS
        if tile_id <= 7:
            normalized = crop_opaque_center(cell).resize(
                (TILE_SIZE, TILE_SIZE),
                Image.Resampling.NEAREST,
            )
        else:
            normalized = fit_object(cell, (TILE_SIZE, TILE_SIZE), (30, 30))
        atlas.alpha_composite(
            normalized,
            (column * TILE_SIZE, row * TILE_SIZE),
        )
    atlas_path.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(atlas_path)
    metadata_path.write_text(
        json.dumps(
            {
                "tile_size": TILE_SIZE,
                "ground_pixels_per_world_unit": GROUND_PIXELS_PER_WORLD_UNIT,
                "ground_pixel_size": list(ground_size),
                "ground_resampled": False,
                "atlas_columns": GRID_COLUMNS,
                "atlas_rows": GRID_ROWS,
                "tiles": [
                    {
                        "id": tile_id,
                        "name": name,
                        "atlas": [
                            tile_id % GRID_COLUMNS,
                            tile_id // GRID_COLUMNS,
                        ],
                        "scene_usage": "terrain" if tile_id <= 7 else "object_sprite",
                    }
                    for tile_id, name in enumerate(TILE_NAMES)
                ],
            },
            indent=2,
        ),
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--source",
        type=Path,
        default=Path("assets/tilesets/vierth_generated_source.png"),
    )
    parser.add_argument(
        "--blueprint",
        type=Path,
        default=Path("data/levels/vierth_entrance_blueprint.json"),
    )
    parser.add_argument(
        "--atlas",
        type=Path,
        default=Path("assets/tilesets/vierth_atlas.png"),
    )
    parser.add_argument(
        "--metadata",
        type=Path,
        default=Path("assets/tilesets/vierth_atlas.json"),
    )
    parser.add_argument(
        "--ground",
        type=Path,
        default=Path("assets/tilesets/vierth_ground.png"),
    )
    parser.add_argument(
        "--objects",
        type=Path,
        default=Path("assets/tilesets/vierth_objects"),
    )
    args = parser.parse_args()

    cleaned_source = remove_magenta(Image.open(args.source))
    cells = split_cells(cleaned_source)
    blueprint = json.loads(args.blueprint.read_text(encoding="utf-8"))
    ground_size = (
        int(blueprint["map_size"][0]) * int(blueprint["tile_size"]),
        int(blueprint["map_size"][1]) * int(blueprint["tile_size"]),
    )
    build_ground(cells, blueprint, args.ground)
    build_objects(cells, args.objects)
    build_compatibility_atlas(
        cells,
        args.atlas,
        args.metadata,
        ground_size,
    )


if __name__ == "__main__":
    main()
