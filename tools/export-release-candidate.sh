#!/usr/bin/env bash
# Export a filtered release tree that excludes local-only and prohibited material.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

# shellcheck disable=SC1091
. "$repo_root/tools/lib/common.sh"

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
    "$candidate/.agent" \
    "$candidate/.agents" \
    "$candidate/.ai" \
    "$candidate/.claude" \
    "$candidate/.codex" \
    "$candidate/.codegraph" \
    "$candidate/.cursor" \
    "$candidate/.kilo" \
    "$candidate/.repowise" \
    "$candidate/.serena" \
    "$candidate/prompt" \
    "$candidate/prompts" \
    "$candidate/agent-prompts" \
    "$candidate/ai-prompts" \
    "$candidate/private" \
    "$candidate/internal" \
    "$candidate/internals" \
    "$candidate/docs/local" \
    "$candidate/docs/internal" \
    "$candidate/docs/agent" \
    "$candidate/docs/agents"
  rm -f \
    "$candidate/AGENT.md" \
    "$candidate/AGENTS.md" \
    "$candidate/agent.md" \
    "$candidate/agents.md" \
    "$candidate/CLAUDE.md" \
    "$candidate/CODEX.md" \
    "$candidate/GEMINI.md" \
    "$candidate/GOAL.md" \
    "$candidate/copilot-instructions.md" \
    "$candidate/.github/copilot-instructions.md" \
    "$candidate/instructions-for-agent.md" \
    "$candidate/agent-instructions.md" \
    "$candidate/notes-for-agent.md" \
    "$candidate/runtimes/linux-compat-connector/linux_connector/docs/assets/lola-wsl-diagnostic-av-validation.png" \
    "$candidate/runtimes/linux-compat-connector/linux_connector/docs/assets/lola-wsl-status-check.png" \
    "$candidate/docs/implementation-handoff.md" \
    "$candidate/docs/archive-binary-retention-proposal.md" \
    "$candidate/tools/verify_docs/archive_topology.txt"

  # These operational WSL screenshots are tracked for connector documentation,
  # but are not approved release rasters.

  # The hygiene gate reports any other prohibited workflow document instead
  # of deleting a potentially legitimate document based only on its filename.
}

# Prune vendored source files that are not selected by the distributable targets.
remove_uncompiled_vendor_artifacts() {
  local vendor_artifacts=(
    "third_party/opus/.github"
    "third_party/opus/.gitlab-ci.yml"
    "third_party/opus/.gitmodules"
    "third_party/opus/celt/tests"
    "third_party/opus/silk/tests"
    "third_party/opus/tests"
    "third_party/opus/dnn"
    "third_party/opus/training"
    "third_party/opus/cmake"
    "third_party/opus/m4"
    "third_party/opus/meson"
    "third_party/opus/autogen.bat"
    "third_party/opus/autogen.sh"
    "third_party/opus/CMakeLists.txt"
    "third_party/opus/configure.ac"
    "third_party/opus/configure"
    "third_party/opus/Makefile.mips"
    "third_party/opus/Makefile.unix"
    "third_party/opus/Makefile.am"
    "third_party/opus/Makefile.in"
    "third_party/opus/meson.build"
    "third_party/opus/meson_options.txt"
    "third_party/opus/opus-uninstalled.pc.in"
    "third_party/opus/opus.m4"
    "third_party/opus/opus.pc.in"
    "third_party/opus/celt_headers.mk"
    "third_party/opus/celt_sources.mk"
    "third_party/opus/silk_headers.mk"
    "third_party/opus/silk_sources.mk"
    "third_party/opus/opus_headers.mk"
    "third_party/opus/opus_sources.mk"
    "third_party/opus/lpcnet_headers.mk"
    "third_party/opus/lpcnet_sources.mk"
    "third_party/jpeg-xs/extras"
    "third_party/jpeg-xs/programs"
    "third_party/jpeg-xs/std"
    "third_party/jpeg-xs/CMakeLists.txt"
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
    relative_path="${opus_source#"$candidate/third_party/opus/"}"
    if ! grep -Fxq -- "$relative_path" "$opus_source_manifest"; then
      rm -f "$opus_source"
    fi
  done < <(find "$candidate/third_party/opus" -type f -name "*.c" -print)
  rm -f "$opus_source_manifest"

  local opus_file
  while IFS= read -r opus_file; do
    relative_path="${opus_file#"$candidate/third_party/opus/"}"
    case "$relative_path" in
      *.c | *.h | COPYING | AUTHORS | README | LICENSE_PLEASE_READ.txt)
        ;;
      *)
        rm -f "$opus_file"
        ;;
    esac
  done < <(find "$candidate/third_party/opus" -type f -print)
  find "$candidate/third_party/opus" -depth -type d -empty -delete
}

# Print the source checkout and destination arguments accepted by the exporter.
usage() {
  cat <<'USAGE'
usage: bash tools/export-release-candidate.sh output-parent-dir

Stages an allowlisted source release candidate outside the raw checkout and
runs tools/verify-release-hygiene.sh against the staged directory. The
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
  "Cargo.toml"
  "Cargo.lock"
  "Makefile"
  "Package.swift"
  "pyproject.toml"
  "uv.lock"
  "LICENSE"
  "NOTICE"
  "LEGAL.md"
  "THIRD_PARTY_NOTICES.md"
  "README.md"
  "RELEASE_STATUS.md"
  "CONTRIBUTING.md"
  "SECURITY.md"
  "CODE_OF_CONDUCT.md"
  "SUPPORT.md"
  "CHANGELOG.md"
  "runtimes"
  "interop"
  "Tests"
  "third_party"
  "tools"
  "web"
  "docs"
)

# Deliberately excluded by the top-level allowlist: .build, archived win-compiled corpus,
# re_out, private evidence, restored reverse-engineering, archive payloads, generated outputs, local LoLa state,
# package artifacts, Python bytecode caches, restored docs/review,
# private/reports, and research/deprecated-research. Test fixtures are staged with Tests so the
# source candidate remains testable; release approval is still blocked until
# fixture provenance is signed off. Vendored codec/reference roots are staged
# only as the Package.swift-selected C source subset plus required headers,
# license/origin metadata, and documented open-lola bridge files. The release
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
OPEN_LOLA_RELEASE_CANDIDATE="$candidate" bash tools/verify-release-hygiene.sh
echo "product release readiness remains PARTIAL until license, notices, reviewer, signing, clean-Mac, hardware, and benchmark gates close."
echo "RELEASE_CANDIDATE_EXPORT_VERDICT: PASS"
