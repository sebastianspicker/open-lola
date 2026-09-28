#!/usr/bin/env bash
# Stage the tracked public source tree outside the checkout for inspection.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
# shellcheck disable=SC1091
. "$repo_root/tools/lib/common.sh"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  echo "usage: bash tools/export-release-candidate.sh output-parent-dir"
  exit 0
fi
[[ $# -eq 1 ]] || fail "expected one output parent directory"
[[ "$1" == /* && "$1" != "/" ]] || fail "output parent must be an absolute directory"
source_revision="$(git rev-parse --verify HEAD)"
source_provenance="CLEAN_COMMIT"
if [[ -n "$(git status --porcelain=v1 --untracked-files=normal)" ]]; then
  [[ "${OPEN_LOLA_ALLOW_DIRTY_INSPECTION:-0}" == "1" ]] ||
    fail "source checkout is dirty; set OPEN_LOLA_ALLOW_DIRTY_INSPECTION=1 for a non-publishable inspection"
  source_provenance="DIRTY_INSPECTION_ONLY"
fi

mkdir -p "$1"
output_parent="$(cd "$1" && pwd -P)"
case "$output_parent/" in
  "$repo_root/"|"$repo_root"/*) fail "output parent must be outside the repository checkout" ;;
esac
stamp="$(date -u '+%Y%m%dT%H%M%SZ')"
candidate="$output_parent/open-lola-source-candidate-$stamp-$$"
mkdir "$candidate"

release_paths=()
while IFS= read -r root_path; do
  release_paths+=("$root_path")
done < <(release_candidate_roots)
for root_path in "${release_paths[@]}"; do
  while IFS= read -r -d '' path; do
    [[ -f "$path" ]] || continue
    mkdir -p "$candidate/$(dirname "$path")"
    cp "$path" "$candidate/$path"
  done < <(git ls-files -z -- "$root_path")
done

echo "release candidate staged at: $candidate"
echo "source revision: $source_revision"
echo "SOURCE_PROVENANCE_VERDICT: $source_provenance"
OPEN_LOLA_RELEASE_CANDIDATE="$candidate" bash tools/verify-release-hygiene.sh
echo "RELEASE_CANDIDATE_EXPORT_VERDICT: PASS"
