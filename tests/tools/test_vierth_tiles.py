from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from PIL import Image

from tools import build_vierth_tiles


PROJECT_ROOT = Path(__file__).resolve().parents[2]


class VierthGroundScaleTest(unittest.TestCase):
    def test_ground_is_one_pixel_per_world_unit(self) -> None:
        blueprint_path = PROJECT_ROOT / "data/levels/vierth_entrance_blueprint.json"
        source_path = PROJECT_ROOT / "assets/tilesets/vierth_generated_source.png"
        blueprint = json.loads(blueprint_path.read_text(encoding="utf-8"))
        expected_size = (
            blueprint["map_size"][0] * blueprint["tile_size"],
            blueprint["map_size"][1] * blueprint["tile_size"],
        )
        cells = build_vierth_tiles.split_cells(
            build_vierth_tiles.remove_magenta(Image.open(source_path))
        )
        with tempfile.TemporaryDirectory() as temporary_directory:
            output = Path(temporary_directory) / "ground.png"
            build_vierth_tiles.build_ground(cells, blueprint, output)
            with Image.open(output) as ground:
                self.assertEqual(ground.size, expected_size)
        self.assertEqual(
            build_vierth_tiles.GROUND_PIXELS_PER_WORLD_UNIT,
            1,
        )


if __name__ == "__main__":
    unittest.main()
