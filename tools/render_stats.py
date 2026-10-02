"""Fill the README's stats blocks from manifest.json, and check SCHEMA.md documents every column.

    python tools/render_stats.py path/to/manifest.json

The numbers in the card are written by this script and never by hand, so a new snapshot
cannot ship with last month's row counts. Exits 1 if a published column is missing from
SCHEMA.md - an undocumented column is how a reader ends up guessing what it means.
"""

from __future__ import annotations

import json
import re
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent

# Derived from the UK estate only, so every row is UK; `buyers` also spans the GB rows of TED.
UK_ONLY = {
    "buyers",
    "suppliers",
    "criterion_roles",
    "frameworks",
    "buyer_routes",
    "documents",
    "tender_documents",
}

GRAIN = {
    "criteria": "one published award criterion (per lot)",
    "notices": "one notice; one notice per lot on `ted_bulk`",
    "outcomes": "one award result per winner; a lot with bid statistics but no award has a NULL winner",
    "buyers": "one raw `buyer_name` spelling → resolved `buyer_id`",
    "suppliers": "one raw `winner_name` spelling → resolved `supplier_id` and company number",
    "criterion_roles": "one raw criterion name → what it is (`price`, `quality`, `social_value`, …)",
    "frameworks": "one multi-supplier award notice, ceiling read once",
    "buyer_routes": "one (authority, CPV division): competed / direct / framework award counts",
    "documents": "one tender-document link cited by a notice",
    "tender_documents": "one document actually opened, with its extracted marking-scheme facts",
}


def replace_block(text: str, name: str, body: str) -> str:
    pattern = re.compile(
        rf"(<!-- stats:{name}:start -->\n).*?(<!-- stats:{name}:end -->)", re.DOTALL
    )
    if not pattern.search(text):
        raise SystemExit(f"README has no stats:{name} block")
    return pattern.sub(lambda m: m.group(1) + body + m.group(2), text)


def main() -> None:
    manifest_path = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE / "manifest.json"
    m = json.loads(manifest_path.read_text())
    if manifest_path.resolve() != (HERE / "manifest.json").resolve():
        shutil.copyfile(manifest_path, HERE / "manifest.json")

    rows = ["| Table | Grain | Rows | of which UK | Size |", "|---|---|---:|---:|---:|"]
    for table, t in m["tables"].items():
        size = sum(f["bytes"] for f in t["files"]) / 1e6
        uk = t.get("rows_by_region", {}).get("uk")
        uk_cell = f"{uk:,}" if uk is not None else "UK only" if table in UK_ONLY else "—"
        rows.append(
            f"| `{table}` | {GRAIN.get(table, '')} | {t['rows']:,} | {uk_cell} | {size:,.0f} MB |"
        )
    total = sum(f["bytes"] for t in m["tables"].values() for f in t["files"]) / 1e9
    rows.append(
        f"\nSnapshot `v{m['version']}`, exported {m['exported_at'][:10]}, **{total:.2f} GB** of zstd Parquet.\n"
    )

    cov = [
        # Rows, not notices: `ted_bulk` is one row per notice x lot, ~4 rows per notice.
        "| `source` | Notice rows | Criteria | Outcomes | First published | Last published |",
        "|---|---:|---:|---:|---|---|",
    ]
    for c in m["coverage"]:
        n = lambda v: f"{v:,}" if v else "—"
        cov.append(
            f"| `{c['source']}` | {n(c['notices'])} | {n(c['criteria'])} | {n(c['outcomes'])} | {c['first']} | {c['last']} |"
        )

    readme = HERE / "README.md"
    text = replace_block(readme.read_text(), "tables", "\n".join(rows) + "\n")
    text = replace_block(text, "coverage", "\n".join(cov) + "\n")
    readme.write_text(text)

    schema = (HERE / "SCHEMA.md").read_text()
    missing = [
        f"{table}.{c['name']}"
        for table, t in m["tables"].items()
        for c in t["columns"]
        if f"`{c['name']}`" not in schema.split(f"## `{table}`", 1)[-1].split("\n## ", 1)[0]
    ]
    if missing:
        print("SCHEMA.md does not document:", ", ".join(missing))
        sys.exit(1)
    print(f"README stats rendered from {manifest_path}; SCHEMA.md covers every column")


if __name__ == "__main__":
    main()
