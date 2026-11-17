"""Verificaciones estáticas del proyecto HotelDB, sin conexión SQL Server."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SQL = ROOT / "Querys"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


class TestRepositoryContracts(unittest.TestCase):
    def test_required_assets_exist(self):
        for rel in (
            "README.md",
            "Querys/Creacion_Hotel.sql",
            "Querys/lnsercion_Hotel.sql",
            "Querys/02_integridad_y_optimizacion.sql",
            "Querys/Vistas.sql",
            "Querys/Consultas de Negocio.sql",
            "Querys/Validacion_Calidad.sql",
            "Dataset/Dataset.xlsx",
            "Power BI - Proyecto/PROYECTO INTEGRADOR.pbix",
            "docs/MODELO_Y_KPIS.md",
        ):
            with self.subTest(path=rel):
                self.assertTrue((ROOT / rel).is_file())

    def test_seed_expected_cardinality(self):
        text = read(SQL / "lnsercion_Hotel.sql")
        for table in ("CLIENTE", "ESTANCIA", "HABITACION",
                      "CLIENTE_HABITACION", "CONSUMO"):
            with self.subTest(table=table):
                count = len(re.findall(
                    rf"^\s*INSERT\s+INTO\s+{table}\s+VALUES\s*\(",
                    text,
                    flags=re.IGNORECASE | re.MULTILINE,
                ))
                self.assertEqual(count, 1000)

    def test_database_creation_is_batch_safe(self):
        sql = read(SQL / "Creacion_Hotel.sql").upper()
        self.assertIn("EXEC(N'CREATE DATABASE [BDHOTEL]')", sql)
        self.assertIn("GO\nUSE [BDHOTEL];\nGO", sql)
        self.assertIn("DECIMAL(12,2)", sql)
        self.assertIn("CHECK (FECHA_SALIDA > FECHA_ENTRADA)", sql)

    def test_links_are_by_stay_not_only_customer(self):
        migration = read(SQL / "02_integridad_y_optimizacion.sql")
        views = read(SQL / "Vistas.sql")
        self.assertIn("FK_CH_ESTANCIA_CLIENTE", migration)
        self.assertIn("FK_CONSUMO_ESTANCIA_CLIENTE", migration)
        self.assertIn("COUNT_BIG(*)", migration)
        self.assertIn("THROW 51000", migration)
        self.assertIn("e.Id_Estancia = ch.Id_Estancia", views)
        self.assertIn("e.Id_Cliente = ch.Id_Cliente", views)
        self.assertIn("th.Id_Tipo_Habitacion = h.Id_Tipo_Habitacion", views)

    def test_analytics_define_time_ranges_and_grains(self):
        views = read(SQL / "Vistas.sql")
        queries = read(SQL / "Consultas de Negocio.sql")
        self.assertIn("'20220101'", views)
        self.assertIn("'20220701'", views)
        self.assertIn("'20221001'", queries)
        self.assertIn("'20230101'", queries)
        self.assertIn("SELECT DISTINCT ch.Id_Estancia, h.Id_Hotel", queries)
        self.assertEqual(
            len(re.findall(r"^-- [1-5]\)", queries, flags=re.MULTILINE)), 5
        )

    def test_migration_is_non_destructive(self):
        sql = read(SQL / "02_integridad_y_optimizacion.sql").upper()
        self.assertNotRegex(sql, r"\bDROP\s+(?:TABLE|DATABASE)\b")
        self.assertIn("BEGIN TRANSACTION", sql)
        self.assertIn("ROLLBACK TRANSACTION", sql)
        self.assertIn("COMMIT TRANSACTION", sql)


if __name__ == "__main__":
    unittest.main()
