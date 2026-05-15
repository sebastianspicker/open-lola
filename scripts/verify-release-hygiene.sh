#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

# shellcheck disable=SC1091
. "$repo_root/scripts/lib/common.sh"

release_boundary_policy="$repo_root/scripts/release-boundary-policy.txt"

manifest_section() {
  local section="$1"
  local in_section=0
  local line

  require_file "$release_boundary_policy"
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    if [[ "$line" == \[*\] ]]; then
      if [[ "$line" == "[$section]" ]]; then
        in_section=1
      else
        in_section=0
      fi
      continue
    fi
    [[ "$in_section" -eq 1 ]] && printf '%s\n' "$line"
  done <"$release_boundary_policy"
}

require_gitignore_pattern() {
  local pattern="$1"

  grep -Fxq -- "$pattern" .gitignore || fail ".gitignore is missing required generated-output exclusion: $pattern"
}

require_no_swiftpm_packages_unless_docs_updated() {
  if grep -Eq '^[[:space:]]*\.package\(' Package.swift; then
    fail "Package.swift declares SwiftPM package dependencies; update docs/compliance/README.md and THIRD_PARTY_NOTICES.md before release"
  fi

  require_file_contains "docs/compliance/README.md" "No external SwiftPM package dependencies"
  require_file_contains "THIRD_PARTY_NOTICES.md" "No external SwiftPM package dependencies"
}

verify_repository_policy() {
  echo "== release hygiene repository policy =="

  require_file ".gitignore"
  require_file "Package.swift"
  require_file "THIRD_PARTY_NOTICES.md"
  require_file "docs/compliance/release-manifest.md"
  require_file "docs/compliance/README.md"

  while IFS= read -r pattern; do
    require_gitignore_pattern "$pattern"
  done < <(manifest_section "gitignore-required")
  require_file_contains ".gitignore" "!.env.example"

  while IFS= read -r path; do
    require_file_contains "docs/compliance/release-manifest.md" "$path"
    require_file_contains "docs/compliance/README.md" "$path"
  done < <(manifest_section "documented-release-exclusion")

  require_file_contains "docs/compliance/release-manifest.md" "Vendor Fence And Patch Policy"
  require_file_contains "docs/compliance/release-manifest.md" "COpus"
  require_file_contains "docs/compliance/release-manifest.md" "CJpegXSReference"
  require_file_contains "docs/compliance/release-manifest.md" "Sources/opus-1.5.2/openlola_bridge/**"
  require_file_contains "docs/compliance/README.md" "Vendor Fence And Patch Policy"
  require_file_contains "THIRD_PARTY_NOTICES.md" "Vendor Fence And Patch Policy"

  require_no_swiftpm_packages_unless_docs_updated
}

find_forbidden_candidate_item() {
  local candidate="$1"

  find "$candidate" \( \
    -name ".build" -o \
    -name ".swiftpm" -o \
    -name "DerivedData" -o \
    -name "win-compiled" -o \
    -name "re_out" -o \
    -path "$candidate/private" -o \
    -path "$candidate/private/*" -o \
    -path "$candidate/reverse-engineering" -o \
    -path "$candidate/reverse-engineering/*" -o \
    -name "archive" -o \
    -path "*/docs/review" -o \
    -path "*/docs/review/*" -o \
    -path "*/docs/mac-port/reports" -o \
    -path "*/docs/mac-port/reports/*" -o \
    -path "*/research/deprecated-research" -o \
    -path "*/research/deprecated-research/*" -o \
    -name "*.dSYM" -o \
    -name "*.xcarchive" -o \
    -name "*.xcresult" -o \
    -name "*.app" -o \
    -name "*.pkg" -o \
    -name "*.dmg" -o \
    -name "*.ipa" -o \
    -name "*.profraw" -o \
    -name "*.profdata" -o \
    -name "__pycache__" -o \
    -name ".pytest_cache" -o \
    -name ".ruff_cache" -o \
    -name ".mypy_cache" -o \
    -name "*.pyc" -o \
    -name "*.pyo" -o \
    -name ".DS_Store" -o \
    -name ".env" -o \
    \( -name ".env.*" ! -name ".env.example" \) -o \
    -name "*.log" -o \
    -name "*.tmp" -o \
    -name "*.ssn" -o \
    -name "LolaGui.ini" -o \
    -name "build.db" -o \
    -name "debug.yaml" -o \
    -name "plugin-tools.yaml" -o \
    -name "*.pcap" -o \
    -name "*.pcapng" -o \
    -path "$candidate/Sources/opus-1.5.2/.github" -o \
    -path "$candidate/Sources/opus-1.5.2/.github/*" -o \
    -path "$candidate/Sources/opus-1.5.2/.gitlab-ci.yml" -o \
    -path "$candidate/Sources/opus-1.5.2/.gitmodules" -o \
    -path "$candidate/Sources/opus-1.5.2/celt/tests" -o \
    -path "$candidate/Sources/opus-1.5.2/celt/tests/*" -o \
    -path "$candidate/Sources/opus-1.5.2/silk/tests" -o \
    -path "$candidate/Sources/opus-1.5.2/silk/tests/*" -o \
    -path "$candidate/Sources/opus-1.5.2/tests" -o \
    -path "$candidate/Sources/opus-1.5.2/tests/*" -o \
    -path "$candidate/Sources/opus-1.5.2/dnn" -o \
    -path "$candidate/Sources/opus-1.5.2/dnn/*" -o \
    -path "$candidate/Sources/opus-1.5.2/training" -o \
    -path "$candidate/Sources/opus-1.5.2/training/*" -o \
    -path "$candidate/Sources/opus-1.5.2/cmake" -o \
    -path "$candidate/Sources/opus-1.5.2/cmake/*" -o \
    -path "$candidate/Sources/opus-1.5.2/m4" -o \
    -path "$candidate/Sources/opus-1.5.2/m4/*" -o \
    -path "$candidate/Sources/opus-1.5.2/meson" -o \
    -path "$candidate/Sources/opus-1.5.2/meson/*" -o \
    -path "$candidate/Sources/opus-1.5.2/autogen.bat" -o \
    -path "$candidate/Sources/opus-1.5.2/autogen.sh" -o \
    -path "$candidate/Sources/opus-1.5.2/CMakeLists.txt" -o \
    -path "$candidate/Sources/opus-1.5.2/configure.ac" -o \
    -path "$candidate/Sources/opus-1.5.2/configure" -o \
    -path "$candidate/Sources/opus-1.5.2/Makefile.mips" -o \
    -path "$candidate/Sources/opus-1.5.2/Makefile.unix" -o \
    -path "$candidate/Sources/opus-1.5.2/Makefile.am" -o \
    -path "$candidate/Sources/opus-1.5.2/Makefile.in" -o \
    -path "$candidate/Sources/opus-1.5.2/meson.build" -o \
    -path "$candidate/Sources/opus-1.5.2/meson_options.txt" -o \
    -path "$candidate/Sources/opus-1.5.2/opus-uninstalled.pc.in" -o \
    -path "$candidate/Sources/opus-1.5.2/opus.m4" -o \
    -path "$candidate/Sources/opus-1.5.2/opus.pc.in" -o \
    -path "$candidate/Sources/opus-1.5.2/celt_headers.mk" -o \
    -path "$candidate/Sources/opus-1.5.2/celt_sources.mk" -o \
    -path "$candidate/Sources/opus-1.5.2/silk_headers.mk" -o \
    -path "$candidate/Sources/opus-1.5.2/silk_sources.mk" -o \
    -path "$candidate/Sources/opus-1.5.2/opus_headers.mk" -o \
    -path "$candidate/Sources/opus-1.5.2/opus_sources.mk" -o \
    -path "$candidate/Sources/opus-1.5.2/lpcnet_headers.mk" -o \
    -path "$candidate/Sources/opus-1.5.2/lpcnet_sources.mk" -o \
    -path "$candidate/Sources/xs_ref_sw_ed2/extras" -o \
    -path "$candidate/Sources/xs_ref_sw_ed2/extras/*" -o \
    -path "$candidate/Sources/xs_ref_sw_ed2/programs" -o \
    -path "$candidate/Sources/xs_ref_sw_ed2/programs/*" -o \
    -path "$candidate/Sources/xs_ref_sw_ed2/std" -o \
    -path "$candidate/Sources/xs_ref_sw_ed2/std/*" -o \
    -path "$candidate/Sources/xs_ref_sw_ed2/CMakeLists.txt" -o \
    -path "$candidate/Sources/xs_ref_sw_ed2/libjxs/CMakeLists.txt" -o \
    -path "$candidate/Sources/xs_ref_sw_ed2/libjxs/src/msbpack.c" \
  \) -print -quit
}

find_forbidden_live_checkout_item() {
  local live_root="$1"

  find "$live_root" \( \
    -path "$live_root/.build" -o \
    -path "$live_root/.build/*" -o \
    -path "$live_root/.swiftpm" -o \
    -path "$live_root/.swiftpm/*" -o \
    -path "$live_root/archive" -o \
    -path "$live_root/archive/*" -o \
    -path "$live_root/dist" -o \
    -path "$live_root/dist/*" -o \
    -path "$live_root/private" -o \
    -path "$live_root/private/*" \
  \) -prune -o \( \
    -name ".DS_Store" -o \
    -name "__pycache__" -o \
    -name "*.pyc" -o \
    -name "*.pyo" -o \
    -name ".pytest_cache" -o \
    -name ".ruff_cache" -o \
    -name ".mypy_cache" \
  \) -print -quit
}

verify_live_checkout() {
  echo "== release hygiene live checkout generated-residue scan =="

  local live_scan_root="${OPEN_LOLA_RELEASE_HYGIENE_LIVE_ROOT:-.}"
  [[ -d "$live_scan_root" ]] || fail "live checkout scan root is not a directory: $live_scan_root"

  local found
  found="$(find_forbidden_live_checkout_item "$live_scan_root")"
  if [[ -n "$found" ]]; then
    fail "live checkout contains forbidden generated artifact before release readiness: $found"
  fi
}

verify_release_candidate() {
  local candidate="$1"

  [[ -d "$candidate" ]] || fail "release candidate path is not a directory: $candidate"
  candidate="$(cd "$candidate" && pwd -P)"

  echo "== release hygiene candidate scan: $candidate =="

  local required_candidate_paths=(
    "Package.swift"
    "pyproject.toml"
    ".github/workflows/release-readiness.yml"
    "Sources/OpenLolaCore"
    "Sources/open-lola"
    "Sources/open-lola-app"
    "Tests/OpenLolaCoreTests"
    "Tests/OpenLolaCoreTests/Fixtures"
    "linux_connector/lola_connector"
    "linux_connector/tests"
    "docs/testing"
    "docs/diagrams"
    "docs/reverse-engineering"
  )

  local path
  for path in "${required_candidate_paths[@]}"; do
    [[ -e "$candidate/$path" ]] || fail "release candidate missing required active surface: $path"
  done

  local required_vendor_paths=(
    "Sources/opus-1.5.2/COPYING"
    "Sources/opus-1.5.2/openlola_bridge/COpusBridge.c"
    "Sources/opus-1.5.2/openlola_bridge/include/COpusBridge.h"
    "Sources/xs_ref_sw_ed2/LICENSE.md"
    "Sources/xs_ref_sw_ed2/libjxs/public"
    "Sources/xs_ref_sw_ed2/libjxs/src"
  )

  for path in "${required_vendor_paths[@]}"; do
    [[ -e "$candidate/$path" ]] || fail "release candidate missing required vendor fence path: $path"
  done

  local found
  found="$(find_forbidden_candidate_item "$candidate")"
  if [[ -n "$found" ]]; then
    fail "release candidate contains forbidden generated/internal/vendor artifact: $found"
  fi
}

main() {
  if [[ $# -gt 1 ]]; then
    fail "usage: bash scripts/verify-release-hygiene.sh [release-candidate-dir]"
  fi

  verify_repository_policy

  local candidate="${1:-${OPEN_LOLA_RELEASE_CANDIDATE:-}}"
  if [[ -n "$candidate" ]]; then
    verify_release_candidate "$candidate"
  else
    verify_live_checkout
    echo "no release candidate supplied; scanned live checkout generated residue only; pass a candidate path for full release-boundary scan"
  fi

  echo "VERDICT: PASS"
}

main "$@"
