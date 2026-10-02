#!/usr/bin/env bash
# Publish one snapshot of BidLens Open Data to Hugging Face.
#
#     tools/publish.sh [EXPORT_DIR] [VERSION]
#
# The data is built in the private bidlens repo (`uv run python -m bidlens.dataset.export_open`
# there), so EXPORT_DIR defaults to its output in a bidlens checkout beside this one, or under
# BIDLENS_ROOT. Everything here runs in this repo's own uv environment (`uv sync` once): the
# bidlens venv is never touched, so a browser harvest running there is safe.
#
# Needs `uv run hf auth login` with a write token for the NodeNovaOrg org.
#
# This repo (github.com/nodenova/bidlens-open-data) carries the card, schema and examples
# without the data; the same files go up to Hugging Face beside the Parquet.

set -euo pipefail
cd "$(dirname "$0")/.."
BIDLENS_ROOT="${BIDLENS_ROOT:-../bidlens}"

EXPORT="${1:-$BIDLENS_ROOT/data/open/bidlens-open-data}"
VERSION="${2:-}"
# The HF org handle is NodeNovaOrg; the GitHub org is nodenova. They are not interchangeable.
REPO="NodeNovaOrg/bidlens-open-data"

[[ -f "$EXPORT/manifest.json" ]] || { echo "no manifest in $EXPORT - run the export first"; exit 2; }
VERSION="${VERSION:-$(uv run python -c "import json,sys; print(json.load(open(sys.argv[1]))['version'])" "$EXPORT/manifest.json")}"

# The version is written by hand in five places (CLAUDE.md, *Releases*). The stats block is
# rendered from the manifest, so a stale hand-written one would ship a card that names two
# snapshots. Refuse before anything is uploaded.
stale=()
grep -q "^version = \"$VERSION\"" pyproject.toml || stale+=(pyproject.toml)
grep -q "^version: \"$VERSION\"" CITATION.cff || stale+=(CITATION.cff)
grep -q "Snapshot \*\*v$VERSION\*\*" README.md || stale+=("README.md intro")
grep -q "version   = {$VERSION}" README.md || stale+=("README.md bibtex")
grep -q "^## v$VERSION" CHANGELOG.md || stale+=(CHANGELOG.md)
if ((${#stale[@]})); then
  echo "version $VERSION (from the manifest) is not in: ${stale[*]}"
  exit 2
fi

# The card's numbers come from this export's manifest, never from the last one. It also copies
# the manifest here, so this repo records which snapshot its card describes.
uv run tools/render_stats.py "$EXPORT/manifest.json"
# Every example must run and return rows on the bytes about to ship.
uv run tools/check_examples.py "$EXPORT"

cp README.md SCHEMA.md LICENSE CITATION.cff CHANGELOG.md "$EXPORT/"
rm -rf "$EXPORT/examples" && cp -R examples "$EXPORT/examples"

uv run hf auth whoami
# Created private: check the dataset viewer renders every config, run
#     uv run tools/check_examples.py hf://datasets/NodeNovaOrg/bidlens-open-data
# then make it public with
#     uv run hf repos settings NodeNovaOrg/bidlens-open-data --type dataset --public
uv run hf repos create "$REPO" --type dataset --private --exist-ok
uv run hf upload "$REPO" "$EXPORT" . --type dataset --commit-message "Snapshot v$VERSION"
# Idempotent, so a re-run after a later failure does not die here. An existing tag is left
# where it is: moving a published tag would change what `revision="v…"` loads for everyone.
if uv run python -c "import sys; from huggingface_hub import list_repo_refs; sys.exit(0 if any(t.name == sys.argv[1] for t in list_repo_refs(sys.argv[2], repo_type='dataset').tags) else 1)" "v$VERSION" "$REPO"; then
  echo "tag v$VERSION already exists - left as it is"
else
  uv run hf repos tag create "$REPO" "v$VERSION" --type dataset -m "Snapshot v$VERSION"
fi
echo "uploaded https://huggingface.co/datasets/$REPO (tag v$VERSION) - private until reviewed"
echo "next: commit the re-rendered card and manifest here, then: git tag v$VERSION && git push --tags"
