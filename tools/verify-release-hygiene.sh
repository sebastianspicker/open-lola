#!/usr/bin/env bash
# Check that the checkout and exported candidate contain only publishable alpha material.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

# shellcheck disable=SC1091
. "$repo_root/tools/lib/common.sh"

release_boundary_policy="$repo_root/tools/release-boundary-policy.txt"
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

# Keep the first-party grant, attribution, and legal boundary present and consistent.
require_licensing_surface() {
  require_file "LICENSE"
  require_file "NOTICE"
  require_file "LEGAL.md"
  require_file_contains "LICENSE" "Apache License"
  require_file_contains "LICENSE" "Version 2.0, January 2004"
  require_file_contains "LICENSE" "Copyright 2026 Open LoLa contributors"
  require_file_contains "NOTICE" "independent educational and research interoperability project"
  require_file_contains "NOTICE" "Conservatorio di Musica Giuseppe Tartini"
  require_file_contains "NOTICE" "does not limit the permissions"
  require_file_contains "LEGAL.md" "field-of-use"
  require_file_contains "LEGAL.md" "grants no rights in original LoLa"
}

# Validate ignore rules, dependency notices, fixture inventory, and vendor-boundary documentation.
verify_repository_policy() {
  echo "== release hygiene repository policy =="

  bash tools/verify-tracked-boundary.sh

  require_file ".gitignore"
  require_file "Package.swift"
  require_file "THIRD_PARTY_NOTICES.md"
  require_file "docs/release-manifest.md"
  require_file "docs/release-boundary.md"

  while IFS= read -r pattern; do
    require_gitignore_pattern "$pattern"
  done < <(manifest_section "gitignore-required")
  require_file_contains ".gitignore" "!.env.example"

  require_file_contains "docs/release-manifest.md" "tools/release-boundary-policy.txt"
  require_file_contains "docs/release-boundary.md" "tools/release-boundary-policy.txt"

  require_file_contains "docs/release-manifest.md" "Vendor Fence And Patch Policy"
  require_file_contains "docs/release-manifest.md" "COpus"
  require_file_contains "docs/release-manifest.md" "CJpegXSReference"
  require_file_contains "docs/release-manifest.md" "third_party/opus/openlola_bridge/**"
  require_file_contains "docs/release-boundary.md" "Vendor Fence And Patch Policy"
  require_file_contains "THIRD_PARTY_NOTICES.md" "Vendor Fence And Patch Policy"

  require_licensing_surface
  require_no_swiftpm_packages_unless_docs_updated
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
    -name "archive" -o \
    -name ".agent" -o \
    -name ".agents" -o \
    -name ".ai" -o \
    -name ".claude" -o \
    -name ".codex" -o \
    -name ".codegraph" -o \
    -name ".cursor" -o \
    -name ".impeccable" -o \
    -name ".kilo" -o \
    -name ".serena" -o \
    -name "prompt" -o \
    -name "prompts" -o \
    -name "agent-prompts" -o \
    -name "ai-prompts" -o \
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
    -name "AGENT.md" -o \
    -name "AGENTS.md" -o \
    -name "agent.md" -o \
    -name "agents.md" -o \
    -name "CLAUDE.md" -o \
    -name "CODEX.md" -o \
    -name "GEMINI.md" -o \
    -name "GOAL.md" -o \
    -iname "copilot-instructions.md" -o \
    -iname "instructions-for-agent.*" -o \
    -iname "agent-instructions.*" -o \
    -iname "notes-for-agent.*" -o \
    -iname "agent-notes*" -o \
    -iname "agent-output*" -o \
    -iname "agent-report*" -o \
    -iname "agent-context*" -o \
    -iname "agent-memory*" -o \
    -iname "AI_NOTES*" -o \
    -iname "AI_REPORT*" -o \
    -iname "AI_AUDIT*" -o \
    -iname "AI_SUMMARY*" -o \
    -iname "AI_REVIEW*" -o \
    -iname "LLM_NOTES*" -o \
    -iname "GPT_NOTES*" -o \
    -iname "CHATGPT_NOTES*" -o \
    -iname "CLAUDE_NOTES*" -o \
    -iname "CODEX_NOTES*" -o \
    -iname "generated-summary.*" -o \
    -iname "repo-analysis.*" -o \
    -iname "repository-analysis.*" -o \
    -iname "audit-output.*" -o \
    -iname "implementation-report.*" -o \
    -iname "completion-report.*" -o \
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
    -path "$candidate/third_party/opus/.github" -o \
    -path "$candidate/third_party/opus/.github/*" -o \
    -path "$candidate/third_party/opus/.gitlab-ci.yml" -o \
    -path "$candidate/third_party/opus/.gitmodules" -o \
    -path "$candidate/third_party/opus/celt/tests" -o \
    -path "$candidate/third_party/opus/celt/tests/*" -o \
    -path "$candidate/third_party/opus/silk/tests" -o \
    -path "$candidate/third_party/opus/silk/tests/*" -o \
    -path "$candidate/third_party/opus/tests" -o \
    -path "$candidate/third_party/opus/tests/*" -o \
    -path "$candidate/third_party/opus/dnn" -o \
    -path "$candidate/third_party/opus/dnn/*" -o \
    -path "$candidate/third_party/opus/training" -o \
    -path "$candidate/third_party/opus/training/*" -o \
    -path "$candidate/third_party/opus/cmake" -o \
    -path "$candidate/third_party/opus/cmake/*" -o \
    -path "$candidate/third_party/opus/m4" -o \
    -path "$candidate/third_party/opus/m4/*" -o \
    -path "$candidate/third_party/opus/meson" -o \
    -path "$candidate/third_party/opus/meson/*" -o \
    -path "$candidate/third_party/opus/autogen.bat" -o \
    -path "$candidate/third_party/opus/autogen.sh" -o \
    -path "$candidate/third_party/opus/CMakeLists.txt" -o \
    -path "$candidate/third_party/opus/configure.ac" -o \
    -path "$candidate/third_party/opus/configure" -o \
    -path "$candidate/third_party/opus/Makefile.mips" -o \
    -path "$candidate/third_party/opus/Makefile.unix" -o \
    -path "$candidate/third_party/opus/Makefile.am" -o \
    -path "$candidate/third_party/opus/Makefile.in" -o \
    -path "$candidate/third_party/opus/meson.build" -o \
    -path "$candidate/third_party/opus/meson_options.txt" -o \
    -path "$candidate/third_party/opus/opus-uninstalled.pc.in" -o \
    -path "$candidate/third_party/opus/opus.m4" -o \
    -path "$candidate/third_party/opus/opus.pc.in" -o \
    -path "$candidate/third_party/opus/celt_headers.mk" -o \
    -path "$candidate/third_party/opus/celt_sources.mk" -o \
    -path "$candidate/third_party/opus/silk_headers.mk" -o \
    -path "$candidate/third_party/opus/silk_sources.mk" -o \
    -path "$candidate/third_party/opus/opus_headers.mk" -o \
    -path "$candidate/third_party/opus/opus_sources.mk" -o \
    -path "$candidate/third_party/opus/lpcnet_headers.mk" -o \
    -path "$candidate/third_party/opus/lpcnet_sources.mk" -o \
    -path "$candidate/third_party/jpeg-xs/extras" -o \
    -path "$candidate/third_party/jpeg-xs/extras/*" -o \
    -path "$candidate/third_party/jpeg-xs/programs" -o \
    -path "$candidate/third_party/jpeg-xs/programs/*" -o \
    -path "$candidate/third_party/jpeg-xs/std" -o \
    -path "$candidate/third_party/jpeg-xs/std/*" -o \
    -path "$candidate/third_party/jpeg-xs/CMakeLists.txt" \
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
    relative_path="${source#"$candidate/third_party/opus/"}"
    if ! grep -Fxq -- "$relative_path" <<<"$selected_sources"; then
      printf '%s\n' "$source"
      return
    fi
  done < <(find "$candidate/third_party/opus" -type f -name "*.c" -print)
}

# Return the first Opus file outside selected C, headers, and required notices.
find_unapproved_candidate_opus_file() {
  local candidate="$1"
  local opus_root="$candidate/third_party/opus"

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

# Require every supplied path in a candidate, preserving the named failure category.
require_candidate_paths() {
  local candidate="$1"
  local failure_kind="$2"
  shift 2
  local path

  for path in "$@"; do
    [[ -e "$candidate/$path" ]] || fail "release candidate missing required $failure_kind: $path"
  done
}

# Require the active public surface and reject nested active documentation trees.
require_active_candidate_surface() {
  local candidate="$1"
  local required_candidate_paths=(
    "LICENSE"
    "NOTICE"
    "LEGAL.md"
    "THIRD_PARTY_NOTICES.md"
    "SUPPORT.md"
    ".python-version"
    "Cargo.toml"
    "Cargo.lock"
    "Makefile"
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
    "runtimes/macos/Sources/OpenLolaCore"
    "runtimes/macos/Sources/open-lola"
    "runtimes/macos/Sources/open-lola-app"
    "runtimes/rust-station/Cargo.toml"
    "interop/lola2/manifest.json"
    "tools/verify_architecture.py"
    "web/demo/index.html"
    "tools/macos/build_and_run.sh"
    "tools/macos/build_cli_app_bundle.sh"
    "tools/macos/generate_brand_assets.sh"
    "tools/macos/render_svg.swift"
    "tools/macos/build_icns.swift"
    "tools/verify_source_documentation.py"
    "docs/README.md"
    "docs/current-state.md"
    "docs/source-contracts.md"
    "docs/testing.md"
    "docs/release-boundary.md"
    "docs/release-manifest.md"
    "docs/RELEASING.md"
    "docs/reverse-engineering-boundary.md"
  )

  require_candidate_paths "$candidate" "active surface" "${required_candidate_paths[@]}"

  local nested_doc_dir
  nested_doc_dir="$(find "$candidate/docs" -mindepth 1 -type d -print -quit)"
  if [[ -n "$nested_doc_dir" ]]; then
    fail "release candidate contains nested active docs directory: ${nested_doc_dir#"$candidate/"}"
  fi
}

# Require the selected source files that fence the vendored codec implementations.
require_candidate_vendor_fence() {
  local candidate="$1"
  local required_vendor_paths=(
    "third_party/opus/COPYING"
    "third_party/opus/AUTHORS"
    "third_party/opus/README"
    "third_party/opus/LICENSE_PLEASE_READ.txt"
    "third_party/opus/openlola_bridge/COpusBridge.c"
    "third_party/opus/openlola_bridge/include/COpusBridge.h"
    "third_party/jpeg-xs/LICENSE.md"
    "third_party/jpeg-xs/README.md"
    "third_party/jpeg-xs/libjxs/CMakeLists.txt"
    "third_party/jpeg-xs/libjxs/public"
    "third_party/jpeg-xs/libjxs/src/msbpack.c"
    "third_party/jpeg-xs/libjxs/src"
  )

  require_candidate_paths "$candidate" "vendor fence path" "${required_vendor_paths[@]}"
}

# Scan an exported candidate for unshipped generated, archival, image, and source material.
verify_candidate_prohibited_content() {
  local candidate="$1"
  local found
  found="$(find_forbidden_candidate_item "$candidate")"
  if [[ -n "$found" ]]; then
    fail "release candidate contains forbidden generated/internal/vendor artifact: $found"
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

# Validate required public surfaces and reject prohibited material in an exported candidate.
verify_release_candidate() {
  local candidate="$1"

  [[ -d "$candidate" ]] || fail "release candidate path is not a directory: $candidate"
  candidate="$(cd "$candidate" && pwd -P)"

  echo "== release hygiene candidate scan: $candidate =="

  require_active_candidate_surface "$candidate"
  require_candidate_vendor_fence "$candidate"
  verify_candidate_prohibited_content "$candidate"
}

# Check that the live checkout and exported candidate contain only publishable alpha material.
main() {
  if [[ $# -gt 1 ]]; then
    fail "usage: bash tools/verify-release-hygiene.sh [release-candidate-dir]"
  fi

  verify_repository_policy

  local candidate="${1:-${OPEN_LOLA_RELEASE_CANDIDATE:-}}"
  if [[ -n "$candidate" ]]; then
    verify_release_candidate "$candidate"
    echo "RELEASE_HYGIENE_VERDICT: PASS"
  elif [[ "${OPEN_LOLA_SKIP_LIVE_RESIDUE:-0}" == "1" ]]; then
    echo "live checkout residue scan -> SKIPPED (preserved local state; verify an exported candidate separately)"
  else
    verify_live_checkout
    echo "no release candidate supplied; scanned live checkout generated residue only; pass a candidate path for full release-boundary scan"
    echo "LIVE_RESIDUE_HYGIENE_VERDICT: PASS"
  fi
}

main "$@"
