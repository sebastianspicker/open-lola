#!/usr/bin/env bash
# Export a filtered release tree that excludes local-only and prohibited material.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

# shellcheck disable=SC1091
. "$repo_root/scripts/lib/common.sh"

# Reject absolute or parent-traversing paths before copying release content.
validate_release_relative_path() {
  local relative_path="$1"
  case "$relative_path" in
    "" | /* | .. | ../* | */.. | */../*)
      fail "invalid release source path: $relative_path"
      ;;
  esac
}

# Copy one approved repository-relative path while preserving its directory shape.
copy_path() {
  local relative_path="$1"

  validate_release_relative_path "$relative_path"
  [[ -e "$relative_path" ]] || fail "missing release source path: $relative_path"

  local parent
  parent="$(dirname "$relative_path")"
  mkdir -p "$candidate/$parent"
  cp -R "$relative_path" "$candidate/$parent/"
}

# Remove caches, build metadata, editor state, logs, and local database residue.
remove_generated_metadata() {
  while IFS= read -r metadata_path; do
    rm -f "$metadata_path"
  done < <(find "$candidate" -type f \( -name ".DS_Store" -o -name "*.pyc" -o -name "*.pyo" \) -print)
  while IFS= read -r cache_path; do
    rm -rf "$cache_path"
  done < <(find "$candidate" -type d \( \
    -name "__pycache__" -o \
    -name ".pytest_cache" -o \
    -name ".ruff_cache" -o \
    -name ".mypy_cache" -o \
    -name ".hypothesis" -o \
    -name ".tox" -o \
    -name ".nox" -o \
    -name ".uv-cache" -o \
    -name "*.egg-info" -o \
    -name "pip-wheel-metadata" \
  \) -print)
}

# Remove private, archived, local-workflow, and reverse-engineering material.
remove_local_only_material() {
  rm -rf \
    "$candidate/.agents" \
    "$candidate/.claude" \
    "$candidate/.codex" \
    "$candidate/.codegraph" \
    "$candidate/.cursor" \
    "$candidate/.serena" \
    "$candidate/private" \
    "$candidate/internal" \
    "$candidate/internals" \
    "$candidate/docs/local" \
    "$candidate/docs/internal" \
    "$candidate/docs/agent" \
    "$candidate/docs/agents"
  rm -f \
    "$candidate/AGENTS.md" \
    "$candidate/CLAUDE.md" \
    "$candidate/GEMINI.md" \
    "$candidate/docs/implementation-handoff.md" \
    "$candidate/docs/archive-binary-retention-proposal.md" \
    "$candidate/scripts/verify_docs/archive_topology.txt"

  # The hygiene gate reports any other prohibited workflow document instead
  # of deleting a potentially legitimate document based only on its filename.
}

# Prune vendored source files that are not selected by the distributable targets.
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
  )

  local relative_path
  for relative_path in "${vendor_artifacts[@]}"; do
    rm -rf "${candidate:?}/$relative_path"
  done

  local opus_source_manifest="$candidate/.release-copus-sources"
  package_copus_sources "$candidate/Package.swift" >"$opus_source_manifest"
  [[ -s "$opus_source_manifest" ]] || fail "Package.swift has no selected COpus sources"

  local opus_source
  while IFS= read -r opus_source; do
    relative_path="${opus_source#"$candidate/Sources/opus-1.5.2/"}"
    if ! grep -Fxq -- "$relative_path" "$opus_source_manifest"; then
      rm -f "$opus_source"
    fi
  done < <(find "$candidate/Sources/opus-1.5.2" -type f -name "*.c" -print)
  rm -f "$opus_source_manifest"

  local opus_file
  while IFS= read -r opus_file; do
    relative_path="${opus_file#"$candidate/Sources/opus-1.5.2/"}"
    case "$relative_path" in
      *.c | *.h | COPYING | AUTHORS | README | LICENSE_PLEASE_READ.txt)
        ;;
      *)
        rm -f "$opus_file"
        ;;
    esac
  done < <(find "$candidate/Sources/opus-1.5.2" -type f -print)
  find "$candidate/Sources/opus-1.5.2" -depth -type d -empty -delete
}

# Print the source checkout and destination arguments accepted by the exporter.
usage() {
  cat <<'USAGE'
usage: bash scripts/export-release-candidate.sh output-parent-dir

Stages an allowlisted source release candidate outside the raw checkout and
runs scripts/verify-release-hygiene.sh against the staged directory. The
source checkout must be clean unless OPEN_LOLA_ALLOW_DIRTY_INSPECTION=1 is set
for an explicitly non-publishable inspection export.
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

source_revision="$(git rev-parse --verify HEAD)"
source_provenance="CLEAN_COMMIT"
if [[ -n "$(git status --porcelain=v1 --untracked-files=normal)" ]]; then
  if [[ "${OPEN_LOLA_ALLOW_DIRTY_INSPECTION:-0}" != "1" ]]; then
    fail "source checkout is dirty; commit an approved tree or set OPEN_LOLA_ALLOW_DIRTY_INSPECTION=1 for a non-publishable inspection export"
  fi
  source_provenance="DIRTY_INSPECTION_ONLY"
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
  ".github"
  ".codacy.yaml"
  ".gitignore"
  ".python-version"
  ".prospector.yaml"
  "Package.swift"
  "pyproject.toml"
  "uv.lock"
  "LICENSE"
  "THIRD_PARTY_NOTICES.md"
  "README.md"
  "RELEASE_STATUS.md"
  "GOAL.md"
  "CONTRIBUTING.md"
  "SECURITY.md"
  "CODE_OF_CONDUCT.md"
  "SUPPORT.md"
  "CHANGELOG.md"
  "archive/README.md"
  "Sources"
  "Tests"
  "linux_connector"
  "scripts"
  "docs"
)

# Deliberately excluded by the top-level allowlist: .build, archived win-compiled corpus,
# re_out, private evidence, restored reverse-engineering, archive payloads, generated outputs, local LoLa state,
# package artifacts, Python bytecode caches, restored docs/review,
# private/reports, and research/deprecated-research. Test fixtures are staged with Tests so the
# source candidate remains testable; release approval is still blocked until
# fixture provenance is signed off. Vendored codec/reference roots are staged
# only as the Package.swift-selected C source subset plus required headers,
# license/origin metadata, and documented open-lola bridge files. The C12
# hygiene scan enforces the same boundary on the staged candidate.
for path in "${release_paths[@]}"; do
  copy_path "$path"
done

remove_generated_metadata
remove_local_only_material
remove_uncompiled_vendor_artifacts

echo "release candidate staged at: $candidate"
echo "source revision: $source_revision"
echo "SOURCE_PROVENANCE_VERDICT: $source_provenance"
OPEN_LOLA_RELEASE_CANDIDATE="$candidate" bash scripts/verify-release-hygiene.sh
echo "product release readiness remains PARTIAL until license, notices, reviewer, signing, clean-Mac, hardware, and benchmark gates close."
echo "RELEASE_CANDIDATE_EXPORT_VERDICT: PASS"
