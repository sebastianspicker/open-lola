#!/usr/bin/env bash
# Verify docs before a local alpha release is declared ready.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

echo "== Active Markdown inventory =="
PYTHONDONTWRITEBYTECODE=1 python3 - <<'PY'
from scripts.verify_docs.markdown_checks import ROOT, docs_from_patterns

for path in docs_from_patterns():
    print(path.relative_to(ROOT))
PY

echo "== Documentation contract =="
PYTHONDONTWRITEBYTECODE=1 python3 -m scripts.verify_docs
