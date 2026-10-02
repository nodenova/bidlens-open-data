"""Run every statement in examples/queries.sql against an export, and fail if any errors or is empty.

    uv run tools/check_examples.py [BASE]

BASE is where the `data/` folder lives: a local export directory (default: the bidlens export
beside this repo) or `hf://datasets/NodeNovaOrg/bidlens-open-data` to test the published copy,
which is the check that the README quick-start works for a stranger. A private repo needs
`hf auth login` first.

An example that returns no rows is a failure too: it means a join or a filter stopped matching,
which is exactly what a reader would hit and not report.
"""

from __future__ import annotations

import os
import re
import sys
import time
from pathlib import Path

import duckdb

HERE = Path(__file__).resolve().parent.parent
QUERIES = HERE / "examples" / "queries.sql"
DEFAULT_BASE = (
    Path(os.environ.get("BIDLENS_ROOT", HERE.parent / "bidlens")) / "data/open/bidlens-open-data"
)


def statements(sql: str) -> list[str]:
    # Comment lines out first so a ';' inside one cannot split a statement.
    body = "\n".join(line for line in sql.splitlines() if not line.lstrip().startswith("--"))
    return [s.strip() for s in body.split(";") if s.strip()]


def main() -> int:
    base = sys.argv[1] if len(sys.argv) > 1 else str(DEFAULT_BASE)
    remote = base.startswith("hf://")
    if not remote and not (Path(base) / "data").is_dir():
        print(f"no data/ under {base}")
        return 2

    sql = QUERIES.read_text().replace("'data/", f"'{base.rstrip('/')}/data/")
    con = duckdb.connect()
    if remote:
        token = os.environ.get("HF_TOKEN") or _cached_token()
        if token:
            con.execute("CREATE SECRET hf (TYPE huggingface, TOKEN ?)", [token])

    failed = 0
    query_no = 0
    for stmt in statements(sql):
        is_view = re.match(r"CREATE\s", stmt, re.IGNORECASE)
        label = "view" if is_view else f"query {(query_no := query_no + 1)}"
        start = time.monotonic()
        try:
            rows = con.execute(stmt).fetchall()
        except duckdb.Error as exc:
            print(f"FAIL {label}: {exc}")
            failed += 1
            continue
        took = time.monotonic() - start
        if not is_view and not rows:
            print(f"FAIL {label}: no rows ({took:.1f}s)")
            failed += 1
        elif not is_view:
            print(f"ok   {label}: {len(rows)} rows ({took:.1f}s)")
    print(f"{query_no} queries, {failed} failed against {base}")
    return 1 if failed else 0


def _cached_token() -> str | None:
    from huggingface_hub import get_token

    return get_token()


if __name__ == "__main__":
    sys.exit(main())
