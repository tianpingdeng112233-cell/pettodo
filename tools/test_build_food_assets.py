#!/usr/bin/env python3
"""Black-box tests for the SPEC-020 food asset build CLI."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image, ImageDraw


FOOD_IDS = (
    "biscuit",
    "chicken_bites",
    "salmon",
    "soft_egg",
    "drumstick",
    "steak",
    "shrimp",
)


class BuildFoodAssetsCliTest(unittest.TestCase):
    def test_builds_complete_validated_food_set(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            sources = root / "sources"
            output = root / "food"
            qa = root / "qa"
            sources.mkdir()
            for index, food_id in enumerate(FOOD_IDS):
                image = Image.new("RGB", (80, 80), "#FF00FF")
                draw = ImageDraw.Draw(image)
                draw.rounded_rectangle(
                    (5, 7, 74, 72),
                    radius=10,
                    fill=(210 + index * 3, 120 + index * 2, 70),
                    outline="#2F2326",
                    width=3,
                )
                image.save(sources / f"{food_id}.png")

            result = subprocess.run(
                [
                    sys.executable,
                    str(Path(__file__).with_name("build_food_assets.py")),
                    "--source-dir",
                    str(sources),
                    "--output-dir",
                    str(output),
                    "--qa-dir",
                    str(qa),
                ],
                capture_output=True,
                text=True,
                check=False,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            manifest = json.loads((output / "manifest.json").read_text())
            self.assertEqual(
                [entry["id"] for entry in manifest["food"]], list(FOOD_IDS)
            )
            self.assertEqual(
                {path.name for path in output.glob("*.png")},
                {f"{food_id}.png" for food_id in FOOD_IDS},
            )
            for food_id in FOOD_IDS:
                image = Image.open(output / f"{food_id}.png")
                self.assertEqual(image.size, (40, 40))
                self.assertEqual(image.mode, "RGBA")
                self.assertLessEqual(len(image.getcolors(maxcolors=1600) or []), 16)
            report = json.loads((qa / "report.json").read_text())
            self.assertTrue(report["passed"])
            self.assertTrue((qa / "contact-sheet.png").is_file())


if __name__ == "__main__":
    unittest.main()
