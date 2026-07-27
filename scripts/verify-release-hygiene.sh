#!/usr/bin/env bash
# Check that the checkout and exported candidate contain only publishable alpha material.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

# shellcheck disable=SC1091
. "$repo_root/scripts/lib/common.sh"

release_boundary_policy="$repo_root/scripts/release-boundary-policy.txt"
python_tool_residue_find_predicate=(
  -name "__pycache__" -o
  -name "*.pyc" -o
  -name "*.pyo" -o
  -name ".pytest_cache" -o
  -name ".ruff_cache" -o
  -name ".mypy_cache" -o
  -name ".venv" -o
  -name "venv" -o
  -name ".uv-cache" -o
  -name ".hypothesis" -o
  -name ".tox" -o
  -name ".nox" -o
  -name "*.egg-info" -o
  -name "pip-wheel-metadata" -o
  -name ".cache"
)

# Emit non-comment entries from one named release-boundary policy section.
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

# Require an exact generated-output exclusion in the repository ignore policy.
require_gitignore_pattern() {
  local pattern="$1"

  grep -Fxq -- "$pattern" .gitignore || fail ".gitignore is missing required generated-output exclusion: $pattern"
}

# Keep dependency declarations and public release notices synchronized.
require_no_swiftpm_packages_unless_docs_updated() {
  if grep -Eq '^[[:space:]]*\.package\(' Package.swift; then
    fail "Package.swift declares SwiftPM package dependencies; update docs/release-boundary.md and THIRD_PARTY_NOTICES.md before release"
  fi

  require_file_contains "docs/release-boundary.md" "No external SwiftPM package dependencies"
  require_file_contains "THIRD_PARTY_NOTICES.md" "No external SwiftPM package dependencies"
}

# Match the fixture counts in third-party notices to the tracked JSON and HEX corpus.
require_fixture_notice_inventory() {
  local json_count
  local hex_count
  json_count="$(find Tests/OpenLolaCoreTests/Fixtures -type f -name "*.json" | wc -l | tr -d '[:space:]')"
  hex_count="$(find Tests/OpenLolaCoreTests/Fixtures -type f -name "*.hex" | wc -l | tr -d '[:space:]')"
  require_file_contains "THIRD_PARTY_NOTICES.md" "$json_count JSON and $hex_count HEX files"
}

# Validate ignore rules, dependency notices, fixture inventory, and vendor-boundary documentation.
verify_repository_policy() {
  echo "== release hygiene repository policy =="

  bash scripts/verify-tracked-boundary.sh

  require_file ".gitignore"
  require_file "Package.swift"
  require_file "THIRD_PARTY_NOTICES.md"
  require_file "docs/release-manifest.md"
  require_file "docs/release-boundary.md"

  while IFS= read -r pattern; do
    require_gitignore_pattern "$pattern"
  done < <(manifest_section "gitignore-required")
  require_file_contains ".gitignore" "!.env.example"

  require_file_contains "docs/release-manifest.md" "scripts/release-boundary-policy.txt"
  require_file_contains "docs/release-boundary.md" "scripts/release-boundary-policy.txt"

  require_file_contains "docs/release-manifest.md" "Vendor Fence And Patch Policy"
  require_file_contains "docs/release-manifest.md" "COpus"
  require_file_contains "docs/release-manifest.md" "CJpegXSReference"
  require_file_contains "docs/release-manifest.md" "Sources/opus-1.5.2/openlola_bridge/**"
  require_file_contains "docs/release-boundary.md" "Vendor Fence And Patch Policy"
  require_file_contains "THIRD_PARTY_NOTICES.md" "Vendor Fence And Patch Policy"

  require_no_swiftpm_packages_unless_docs_updated
  require_fixture_notice_inventory
}

# Return the first generated, private, credential-like, or unshipped item in a candidate.
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
    \( -name "archive" ! -path "$candidate/archive" \) -o \
    -name ".agents" -o \
    -name ".claude" -o \
    -name ".codex" -o \
    -name ".codegraph" -o \
    -name ".cursor" -o \
    -name ".impeccable" -o \
    -name ".serena" -o \
    -path "*/docs/review" -o \
    -path "*/docs/review/*" -o \
    -path "*/private/reports" -o \
    -path "*/private/reports/*" -o \
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
    "${python_tool_residue_find_predicate[@]}" -o \
    -name ".codacy" -o \
    -name ".vscode" -o \
    -name ".idea" -o \
    -name ".fleet" -o \
    -name ".history" -o \
    -name "*.pyc" -o \
    -name "*.pyo" -o \
    -name ".DS_Store" -o \
    -name ".env" -o \
    \( -name ".env.*" ! -name ".env.example" \) -o \
    -iname "plan.md" -o \
    -iname "plan-*.md" -o \
    -iname "*-plan.md" -o \
    -iname "*-plan-*.md" -o \
    -name "AGENTS.md" -o \
    -name "CLAUDE.md" -o \
    -name "GEMINI.md" -o \
    -iname "*audit*.md" -o \
    -iname "*remediation*.md" -o \
    -iname "*ledger*.md" -o \
    -name "*.log" -o \
    -name "*.tmp" -o \
    -name "*.ssn" -o \
    -name "LolaGui.ini" -o \
    -name "build.db" -o \
    -name "debug.yaml" -o \
    -name "plugin-tools.yaml" -o \
    -name "*.pcap" -o \
    -name "*.pcapng" -o \
    -name "*.key" -o \
    -name "*.pem" -o \
    -name "*.p12" -o \
    -name "*.pfx" -o \
    -name "*.jks" -o \
    -name "*.keystore" -o \
    -name "*.mobileprovision" -o \
    -name "credentials.json" -o \
    -name "secrets.json" -o \
    -name "auth.json" -o \
    -name "*.db" -o \
    -name "*.db-shm" -o \
    -name "*.db-wal" -o \
    -name "*.sqlite" -o \
    -name "*.sqlite3" -o \
    -name "*.sarif" -o \
    -path "$candidate/reports" -o \
    -path "$candidate/reports/*" -o \
    -path "$candidate/artifacts" -o \
    -path "$candidate/artifacts/*" -o \
    -path "$candidate/build" -o \
    -path "$candidate/build/*" -o \
    -path "$candidate/dist" -o \
    -path "$candidate/dist/*" -o \
    -path "$candidate/local" -o \
    -path "$candidate/local/*" -o \
    -path "$candidate/tmp" -o \
    -path "$candidate/tmp/*" -o \
    -path "$candidate/scratch" -o \
    -path "$candidate/scratch/*" -o \
    -path "$candidate/out" -o \
    -path "$candidate/out/*" -o \
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
    -path "$candidate/Sources/xs_ref_sw_ed2/CMakeLists.txt" \
  \) -print -quit
}

# Return the first candidate raster image outside the approved brand and UI assets.
find_unapproved_candidate_image() {
  local candidate="$1"

  find "$candidate" -type f \( \
    -iname "*.png" -o \
    -iname "*.jpg" -o \
    -iname "*.jpeg" -o \
    -iname "*.gif" -o \
    -iname "*.webp" -o \
    -iname "*.heic" -o \
    -iname "*.tif" -o \
    -iname "*.tiff" -o \
    -iname "*.bmp" \
  \) \
    ! -path "$candidate/.github/assets/open-lola-signal-desk-light.png" \
    ! -path "$candidate/.github/assets/open-lola-signal-desk-dark.png" \
    ! -path "$candidate/.github/assets/open-lola-social-preview.png" \
    -print -quit
}

# Return archive content other than the single public archive index.
find_forbidden_candidate_archive_item() {
  local candidate="$1"

  find "$candidate/archive" -mindepth 1 \
    ! -path "$candidate/archive/README.md" \
    -print -quit
}

# Return the first vendored Opus C file not selected by the SwiftPM target.
find_unselected_candidate_opus_source() {
  local candidate="$1"
  local selected_sources
  selected_sources="$(package_copus_sources "$candidate/Package.swift")"

  if [[ -z "$selected_sources" ]]; then
    printf '%s\n' "$candidate/Package.swift"
    return
  fi

  local source
  local relative_path
  while IFS= read -r source; do
    relative_path="${source#"$candidate/Sources/opus-1.5.2/"}"
    if ! grep -Fxq -- "$relative_path" <<<"$selected_sources"; then
      printf '%s\n' "$source"
      return
    fi
  done < <(find "$candidate/Sources/opus-1.5.2" -type f -name "*.c" -print)
}

# Return the first Opus file outside selected C, headers, and required notices.
find_unapproved_candidate_opus_file() {
  local candidate="$1"
  local opus_root="$candidate/Sources/opus-1.5.2"

  find "$opus_root" -type f \
    ! -name "*.c" \
    ! -name "*.h" \
    ! -path "$opus_root/COPYING" \
    ! -path "$opus_root/AUTHORS" \
    ! -path "$opus_root/README" \
    ! -path "$opus_root/LICENSE_PLEASE_READ.txt" \
    -print -quit
}

# Return the first generated cache or local-only directory visible in the live checkout.
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
    "${python_tool_residue_find_predicate[@]}" -o \
    -name ".codacy" -o \
    -name ".impeccable" \
  \) -print -quit
}

# Fail release readiness when generated residue remains in the configured checkout root.
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

# Validate required public surfaces and reject prohibited material in an exported candidate.
verify_release_candidate() {
  local candidate="$1"

  [[ -d "$candidate" ]] || fail "release candidate path is not a directory: $candidate"
  candidate="$(cd "$candidate" && pwd -P)"

  echo "== release hygiene candidate scan: $candidate =="

  local required_candidate_paths=(
    "RELEASE_STATUS.md"
    "SUPPORT.md"
    "archive/README.md"
    ".python-version"
    "Package.swift"
    "pyproject.toml"
    ".github/workflows/release-readiness.yml"
    ".github/assets/OpenLoLa.icns"
    ".github/assets/open-lola-app-icon.svg"
    ".github/assets/open-lola-mark-light.svg"
    ".github/assets/open-lola-mark-dark.svg"
    ".github/assets/open-lola-social-preview.svg"
    ".github/assets/open-lola-social-preview.png"
    ".github/assets/open-lola-signal-desk-light.png"
    ".github/assets/open-lola-signal-desk-dark.png"
    "Sources/OpenLolaCore"
    "Sources/open-lola"
    "Sources/open-lola-app"
    "Tests/OpenLolaCoreTests"
    "Tests/OpenLolaCoreTests/Fixtures"
    "linux_connector/lola_connector"
    "linux_connector/tests"
    "scripts/macos/build_and_run.sh"
    "scripts/macos/build_cli_app_bundle.sh"
    "scripts/macos/generate_brand_assets.sh"
    "scripts/macos/render_svg.swift"
    "scripts/macos/build_icns.swift"
    "scripts/verify_source_documentation.py"
    "docs/README.md"
    "docs/current-state.md"
    "docs/source-contracts.md"
    "docs/testing.md"
    "docs/release-boundary.md"
    "docs/release-manifest.md"
    "docs/RELEASING.md"
    "docs/reverse-engineering-boundary.md"
  )

  local path
  for path in "${required_candidate_paths[@]}"; do
    [[ -e "$candidate/$path" ]] || fail "release candidate missing required active surface: $path"
  done

  local nested_doc_dir
  nested_doc_dir="$(find "$candidate/docs" -mindepth 1 -type d -print -quit)"
  if [[ -n "$nested_doc_dir" ]]; then
    fail "release candidate contains nested active docs directory: ${nested_doc_dir#"$candidate/"}"
  fi

  local required_vendor_paths=(
    "Sources/opus-1.5.2/COPYING"
    "Sources/opus-1.5.2/AUTHORS"
    "Sources/opus-1.5.2/README"
    "Sources/opus-1.5.2/LICENSE_PLEASE_READ.txt"
    "Sources/opus-1.5.2/openlola_bridge/COpusBridge.c"
    "Sources/opus-1.5.2/openlola_bridge/include/COpusBridge.h"
    "Sources/xs_ref_sw_ed2/LICENSE.md"
    "Sources/xs_ref_sw_ed2/README.md"
    "Sources/xs_ref_sw_ed2/libjxs/CMakeLists.txt"
    "Sources/xs_ref_sw_ed2/libjxs/public"
    "Sources/xs_ref_sw_ed2/libjxs/src/msbpack.c"
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

  found="$(find_forbidden_candidate_archive_item "$candidate")"
  if [[ -n "$found" ]]; then
    fail "release candidate contains forbidden generated/internal/vendor artifact: $found (archive payload)"
  fi

  found="$(find_unapproved_candidate_image "$candidate")"
  if [[ -n "$found" ]]; then
    fail "release candidate contains forbidden generated/internal/vendor artifact: $found (unapproved image or screenshot)"
  fi

  found="$(find_unselected_candidate_opus_source "$candidate")"
  if [[ -n "$found" ]]; then
    fail "release candidate contains forbidden generated/internal/vendor artifact: $found (C source not selected by Package.swift COpus target)"
  fi

  found="$(find_unapproved_candidate_opus_file "$candidate")"
  if [[ -n "$found" ]]; then
    fail "release candidate contains forbidden generated/internal/vendor artifact: $found (uncompiled Opus helper or build file)"
  fi
}

# Check that the live checkout and exported candidate contain only publishable alpha material.
main() {
  if [[ $# -gt 1 ]]; then
    fail "usage: bash scripts/verify-release-hygiene.sh [release-candidate-dir]"
  fi

  verify_repository_policy

  local candidate="${1:-${OPEN_LOLA_RELEASE_CANDIDATE:-}}"
  if [[ -n "$candidate" ]]; then
    verify_release_candidate "$candidate"
    echo "RELEASE_HYGIENE_VERDICT: PASS"
  else
    verify_live_checkout
    echo "no release candidate supplied; scanned live checkout generated residue only; pass a candidate path for full release-boundary scan"
    echo "LIVE_RESIDUE_HYGIENE_VERDICT: PASS"
  fi
}

main "$@"
