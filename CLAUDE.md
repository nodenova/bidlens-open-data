# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Card, schema, example queries and publish tooling for the Hugging Face dataset
`NodeNovaOrg/bidlens-open-data`. The Parquet data is never stored here. It is exported by the
private `bidlens` repo to `../bidlens/data/open/bidlens-open-data` (or under `$BIDLENS_ROOT`).

## Commands

- `uv sync` once. All tooling runs through `uv run`, never the bidlens venv.
- `uv run tools/check_examples.py [BASE]`: the test suite. Runs every statement in
  `examples/queries.sql` against a local export (default) or
  `hf://datasets/NodeNovaOrg/bidlens-open-data`. A query that returns zero rows fails.
- `uv run tools/render_stats.py [EXPORT/manifest.json]`: regenerates the README stats blocks,
  copies the manifest here, and fails if `SCHEMA.md` is missing a column.
- `uvx ruff check tools && uvx ruff format tools`: ruff is configured but not a dependency.
- `tools/publish.sh` uploads and tags on Hugging Face. Only run it when asked.

## Gotchas

- IMPORTANT: before writing any query, example or analysis prose, read "Read this before
  analysing" in `README.md`. Every trap listed there gives a plausible wrong number with no
  error (for example, jurisdiction comes from `source`, not `country`).
- Never hand-edit the README content between `<!-- stats:*:start -->` and `<!-- stats:*:end -->`.
  `render_stats.py` overwrites it from `manifest.json`.
- A new export column needs a row in `SCHEMA.md` under its exact `` ## `table` `` heading. A new
  table also needs entries in `GRAIN` and `UK_ONLY` in `tools/render_stats.py`, and a config in
  the README YAML front matter, which is the Hugging Face card config. Its globs must match the
  export's `<table>-uk-*` / `<table>-other-*` file names.
- `check_examples.py` splits `queries.sql` on `;` after dropping `--` lines. Don't put `;` inside
  string literals, and write paths as `'data/<table>/*.parquet'` so the script can rewrite them.
- The Hugging Face org is `NodeNovaOrg`; the GitHub org is `nodenova`. They are not interchangeable.

## Releases

- Snapshots are tagged `v<YYYY.MM>` on both Hugging Face and GitHub. Bump the version in
  `pyproject.toml`, `CITATION.cff`, the README (intro line and bibtex) and `CHANGELOG.md` together.
- `publish.sh` leaves the dataset private. Making it public, committing the re-rendered card and
  `manifest.json`, and pushing the git tag are manual steps afterwards.
