#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

echo "== Active Markdown inventory =="
find . -maxdepth 3 \
  \( \
    -path './.build' \
    -o -path './.pytest_cache' \
    -o -path './.ruff_cache' \
    -o -path './re_out' \
    -o -path './archive' \
    -o -path './private' \
    -o -path './Sources/opus-1.5.2' \
    -o -path './Sources/xs_ref_sw_ed2' \
  \) -prune \
  -o -type f -name '*.md' -print | sort
find docs -maxdepth 5 \
  \( -path 'docs/historical' -o -path 'docs/review' \) -prune \
  -o -type f -name '*.md' -print 2>/dev/null | sort

if [[ "${OPEN_LOLA_PUBLIC_DOCS_ONLY:-0}" != "1" ]]; then
  echo "== Archived Markdown inventory =="
  PYTHONDONTWRITEBYTECODE=1 python3 -m scripts.verify_docs.archive_inventory roots | while IFS= read -r archive_root; do
    [[ -d "$archive_root" ]] || continue
    find "$archive_root" -type f -name '*.md' -print | sort
  done
else
  echo "== Archived Markdown inventory skipped for public-docs-only verification =="
fi

echo "== Documentation contract =="
PYTHONDONTWRITEBYTECODE=1 python3 -m scripts.verify_docs
