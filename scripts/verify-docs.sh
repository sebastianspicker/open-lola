#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

echo "== Active Markdown inventory =="
find . -maxdepth 3 \
  \( -path './.build' -o -path './.pytest_cache' -o -path './.ruff_cache' -o -path './re_out' -o -path './archive' \) -prune \
  -o -type f -name '*.md' -print | sort
find docs -maxdepth 5 \
  \( -path 'docs/historical' -o -path 'docs/review' \) -prune \
  -o -type f -name '*.md' -print 2>/dev/null | sort

echo "== Archived Markdown inventory =="
PYTHONDONTWRITEBYTECODE=1 python3 -m scripts.verify_docs.archive_inventory roots | while IFS= read -r archive_root; do
  [[ -d "$archive_root" ]] || continue
  find "$archive_root" -type f -name '*.md' -print | sort
done

echo "== Documentation contract =="
PYTHONDONTWRITEBYTECODE=1 python3 -m scripts.verify_docs
