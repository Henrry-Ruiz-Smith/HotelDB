"""Contratos de dashboard y métricas 2022."""
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from build_dashboard_data import build_dataset  # noqa: E402


class TestDashboard(unittest.TestCase):
    def test_dataset_matches_sql(self):
        raw = (ROOT / "dashboard" / "data.js").read_text(encoding="utf-8")
        prefix = "window.HOTELDB_DATA = "
        self.assertTrue(raw.startswith(prefix) and raw.endswith(";\n"))
        dataset = json.loads(raw[len(prefix):-2])
        self.assertEqual(dataset, build_dataset())
        self.assertEqual(len(dataset["rows"]), 1000)
        self.assertTrue(all(len(row) == 10 for row in dataset["rows"]))

    def test_kpis_from_seed(self):
        rows = build_dataset()["rows"]
        self.assertEqual(sum(row[6] for row in rows), 3180050)
        self.assertEqual(sum(row[8] for row in rows), 3998010)
        self.assertEqual(sum(row[5] for row in rows), 2791)
        self.assertEqual(sum(row[7] for row in rows), 2871)
        self.assertEqual(sum(row[4] >= 3 for row in rows), 749)
        self.assertEqual({row[2] for row in rows}, set(range(1, 13)))

    def test_visual_assets(self):
        svg = (ROOT / "dashboard" / "preview.svg").read_text(encoding="utf-8")
        html = (ROOT / "dashboard" / "index.html").read_text(encoding="utf-8")
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        self.assertIn("<svg", svg)
        self.assertIn("3.180.050", svg)
        self.assertIn("74,9 %", svg)
        self.assertIn('src="./data.js"', html)
        self.assertIn('id="filter-month"', html)
        self.assertIn('id="filter-room"', html)
        self.assertIn("dashboard/preview.svg", readme)

    def test_dashboard_contains_no_pii(self):
        data = (ROOT / "dashboard" / "data.js").read_text(encoding="utf-8")
        svg = (ROOT / "dashboard" / "preview.svg").read_text(encoding="utf-8")
        for pii in ("DNI", "FechaNac", "Mario Casas", "51963569850", "Telefono"):
            with self.subTest(pii=pii):
                self.assertNotIn(pii, data)
                self.assertNotIn(pii, svg)


if __name__ == "__main__":
    unittest.main()
