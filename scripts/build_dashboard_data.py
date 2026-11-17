"""Genera el dataset web seguro desde el SQL original (sin datos personales).

Uso: python scripts/build_dashboard_data.py [--check]
El seed actual vincula una estancia, una asignación y un consumo por cliente.
No inferir estancias cuando el origen deja de tener esa cardinalidad.
"""
import argparse
import json
import re
from datetime import date
from decimal import Decimal
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Querys" / "lnsercion_Hotel.sql"
TARGET = ROOT / "dashboard" / "data.js"


def sql_values(fragment):
    fragment = fragment.strip()
    if not fragment.startswith("("):
        return None
    fragment = re.sub(r"\)\s*[,;]?\s*$", "", fragment[1:])
    out, token, quoted = [], [], False
    i = 0
    while i < len(fragment):
        char = fragment[i]
        if char == "'":
            if quoted and i + 1 < len(fragment) and fragment[i + 1] == "'":
                token.append("'")
                i += 1
            else:
                quoted = not quoted
        elif char == "," and not quoted:
            out.append("".join(token).strip())
            token = []
        else:
            token.append(char)
        i += 1
    if quoted:
        raise ValueError("SQL: literal sin cerrar")
    out.append("".join(token).strip())
    return out


def parse_seed():
    tables, current = {}, ""
    for line in SOURCE.read_text(encoding="utf-8").splitlines():
        match = re.match(
            r"^\s*INSERT\s+INTO\s+([A-Za-z_]+)\s+VALUES\s*(.*)",
            line, flags=re.IGNORECASE,
        )
        if match:
            current = match[1].upper()
            fields = sql_values(match[2])
            if fields is not None:
                tables.setdefault(current, []).append(fields)
        elif current and line.lstrip().startswith("("):
            fields = sql_values(line)
            if fields is not None:
                tables.setdefault(current, []).append(fields)
    return tables


def build_dataset():
    tables = parse_seed()

    def mapping(table):
        return {row[0]: row for row in tables[table]}

    def catalog(table, column=1):
        rows = tables[table]
        return [row[column] for row in rows], {row[0]: i for i, row in enumerate(rows)}

    hotels, hotel_ids = catalog("HOTEL")
    room_types, room_ids = catalog("TIPO_HABITACION")
    payments, payment_ids = catalog("MODO_PAGO")
    satisfaction, satisfaction_ids = catalog("SATISFACCION")
    categories, category_ids = catalog("TIPO_CONSUMIBLE")

    rooms = mapping("HABITACION")
    types = mapping("TIPO_HABITACION")
    items = mapping("CONSUMIBLE")

    stays = {}
    for row in tables["ESTANCIA"]:
        if row[4] in stays:
            raise ValueError("Cliente con varias estancias: requiere mapeo explícito")
        stays[row[4]] = row
    consumptions = {}
    for row in tables["CONSUMO"]:
        if row[3] in consumptions:
            raise ValueError("Consumos múltiples: revisar granularidad estancia")
        consumptions[row[3]] = row

    rows, seen = [], set()
    for link in tables["CLIENTE_HABITACION"]:
        client_id = link[1]
        if client_id in seen:
            raise ValueError("Varias habitaciones para cliente: revisar grano")
        seen.add(client_id)
        stay, room, consumption = stays[client_id], rooms[link[2]], consumptions[client_id]
        item = items[consumption[1]]
        nights = (date.fromisoformat(stay[2]) - date.fromisoformat(stay[1])).days
        if nights <= 0:
            raise ValueError("Estancia con fechas inválidas")
        room_price = int(types[room[3]][2])
        qty = int(consumption[2])
        unit_cents = int(Decimal(item[3]) * 100)
        rows.append([
            hotel_ids[room[2]], room_ids[room[3]], date.fromisoformat(stay[1]).month,
            payment_ids[stay[3]], satisfaction_ids[link[3]], nights,
            nights * room_price, qty, unit_cents * qty, category_ids[item[1]],
        ])

    if len(rows) != len(stays) or len(rows) != len(consumptions):
        raise ValueError("Seed no cumple cardinalidad 1:1 esperada")

    return {
        "meta": {
            "period": "2022", "currency": "PEN",
            "source": "Querys/lnsercion_Hotel.sql", "generatedFrom": "demo-seed",
        },
        "hotels": hotels, "roomTypes": room_types,
        "payments": payments, "satisfaction": satisfaction,
        "categories": categories, "rows": rows,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Comprueba data.js sin modificarlo")
    args = parser.parse_args()
    output = ("window.HOTELDB_DATA = "
              + json.dumps(build_dataset(), ensure_ascii=False, separators=(",", ":"))
              + ";\n")
    if args.check:
        if not TARGET.exists() or TARGET.read_text(encoding="utf-8") != output:
            parser.error("data.js obsoleto. Ejecute: python scripts/build_dashboard_data.py")
        print("OK: dashboard/data.js coincide con el seed SQL.")
    else:
        TARGET.parent.mkdir(parents=True, exist_ok=True)
        TARGET.write_text(output, encoding="utf-8")
        print("Regenerado:", TARGET)


if __name__ == "__main__":
    main()
