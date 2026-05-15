#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

# shellcheck disable=SC1091
. "$repo_root/scripts/lib/common.sh"

validate_release_relative_path() {
  local relative_path="$1"
  case "$relative_path" in
    "" | /* | .. | ../* | */.. | */../*)
      fail "invalid release source path: $relative_path"
      ;;
  esac
}

copy_path() {
  local relative_path="$1"

  validate_release_relative_path "$relative_path"
  [[ -e "$relative_path" ]] || fail "missing release source path: $relative_path"

  local parent
  parent="$(dirname "$relative_path")"
  mkdir -p "$candidate/$parent"
  cp -R "$relative_path" "$candidate/$parent/"
}

remove_generated_metadata() {
  while IFS= read -r metadata_path; do
    rm -f "$metadata_path"
  done < <(find "$candidate" -type f \( -name ".DS_Store" -o -name "*.pyc" -o -name "*.pyo" \) -print)
  while IFS= read -r cache_path; do
    rm -rf "$cache_path"
  done < <(find "$candidate" -type d \( -name "__pycache__" -o -name ".pytest_cache" -o -name ".ruff_cache" -o -name ".mypy_cache" \) -print)
}

remove_uncompiled_vendor_artifacts() {
  local vendor_artifacts=(
    "Sources/opus-1.5.2/.github"
    "Sources/opus-1.5.2/.gitlab-ci.yml"
    "Sources/opus-1.5.2/.gitmodules"
    "Sources/opus-1.5.2/celt/tests"
    "Sources/opus-1.5.2/silk/tests"
    "Sources/opus-1.5.2/tests"
    "Sources/opus-1.5.2/dnn"
    "Sources/opus-1.5.2/training"
    "Sources/opus-1.5.2/cmake"
    "Sources/opus-1.5.2/m4"
    "Sources/opus-1.5.2/meson"
    "Sources/opus-1.5.2/autogen.bat"
    "Sources/opus-1.5.2/autogen.sh"
    "Sources/opus-1.5.2/CMakeLists.txt"
    "Sources/opus-1.5.2/configure.ac"
    "Sources/opus-1.5.2/configure"
    "Sources/opus-1.5.2/Makefile.mips"
    "Sources/opus-1.5.2/Makefile.unix"
    "Sources/opus-1.5.2/Makefile.am"
    "Sources/opus-1.5.2/Makefile.in"
    "Sources/opus-1.5.2/meson.build"
    "Sources/opus-1.5.2/meson_options.txt"
    "Sources/opus-1.5.2/opus-uninstalled.pc.in"
    "Sources/opus-1.5.2/opus.m4"
    "Sources/opus-1.5.2/opus.pc.in"
    "Sources/opus-1.5.2/celt_headers.mk"
    "Sources/opus-1.5.2/celt_sources.mk"
    "Sources/opus-1.5.2/silk_headers.mk"
    "Sources/opus-1.5.2/silk_sources.mk"
    "Sources/opus-1.5.2/opus_headers.mk"
    "Sources/opus-1.5.2/opus_sources.mk"
    "Sources/opus-1.5.2/lpcnet_headers.mk"
    "Sources/opus-1.5.2/lpcnet_sources.mk"
    "Sources/xs_ref_sw_ed2/extras"
    "Sources/xs_ref_sw_ed2/programs"
    "Sources/xs_ref_sw_ed2/std"
    "Sources/xs_ref_sw_ed2/CMakeLists.txt"
    "Sources/xs_ref_sw_ed2/libjxs/CMakeLists.txt"
    "Sources/xs_ref_sw_ed2/libjxs/src/msbpack.c"
  )

  local relative_path
  for relative_path in "${vendor_artifacts[@]}"; do
    rm -rf "${candidate:?}/$relative_path"
  done
}

usage() {
  cat <<'USAGE'
usage: bash scripts/export-release-candidate.sh output-parent-dir

Stages an allowlisted source release candidate outside the raw checkout and
runs scripts/verify-release-hygiene.sh against the staged directory.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -ne 1 ]]; then
  usage >&2
  fail "expected one explicit output parent directory"
fi

output_parent="$1"
mkdir -p "$output_parent"
output_parent="$(cd "$output_parent" && pwd -P)"

case "$output_parent/" in
  "$repo_root/" | "$repo_root"/*)
    fail "output parent must be outside the repository checkout"
    ;;
esac

stamp="$(date -u '+%Y%m%dT%H%M%SZ')"
candidate="$output_parent/open-lola-source-candidate-$stamp-$$"
mkdir "$candidate"

release_paths=(
  ".github/workflows/release-readiness.yml"
  ".gitignore"
  "Package.swift"
  "pyproject.toml"
  "LICENSE"
  "THIRD_PARTY_NOTICES.md"
  "README.md"
  "GOAL.md"
  "Sources"
  "Tests"
  "linux_connector"
  "scripts"
  "docs/README.md"
  "docs/current-state.md"
  "docs/architecture"
  "docs/benchmarks"
  "docs/compliance"
  "docs/diagrams"
  "docs/mac-port"
  "docs/reverse-engineering"
  "docs/background"
  "docs/roadmap"
  "docs/source-contracts"
  "docs/testing"
)

# Deliberately excluded by the allowlist: .build, archived win-compiled corpus,
# re_out, private evidence, restored reverse-engineering, archive, generated outputs, local LoLa state,
# package artifacts, Python bytecode caches, restored docs/review,
# docs/mac-port/reports, and research/deprecated-research. Test fixtures are staged with Tests so the
# source candidate remains testable; release approval is still blocked until
# fixture provenance is signed off. Vendored codec/reference roots are staged
# only as the Package.swift-selected build subset plus license/origin metadata
# and documented open-lola bridge files. The C12 hygiene scan enforces the same
# boundary on the staged candidate.
for path in "${release_paths[@]}"; do
  copy_path "$path"
done

remove_generated_metadata
remove_uncompiled_vendor_artifacts

echo "release candidate staged at: $candidate"
OPEN_LOLA_RELEASE_CANDIDATE="$candidate" bash scripts/verify-release-hygiene.sh
echo "product release readiness remains PARTIAL until license, notices, reviewer, signing, clean-Mac, hardware, and benchmark gates close."
echo "VERDICT: PASS"
