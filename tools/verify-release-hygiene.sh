#!/usr/bin/env bash
# Check the public source boundary in the checkout or a staged candidate.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
# shellcheck disable=SC1091
. "$repo_root/tools/lib/common.sh"

verify_repository_policy() {
  bash tools/verify-tracked-boundary.sh
  require_file "LICENSE"
  require_file "NOTICE"
  require_file "LEGAL.md"
  require_file "THIRD_PARTY_NOTICES.md"
  require_file "Package.swift"
  require_file "docs/release-manifest.md"
  require_file "tools/release-boundary-policy.txt"
  require_file_contains "LICENSE" "Apache License"
  require_file_contains "LICENSE" "Copyright 2026 Open LoLa contributors"
  while IFS= read -r pattern; do
    grep -Fxq -- "$pattern" .gitignore || fail ".gitignore is missing required pattern: $pattern"
  done < <(awk '/^\[gitignore-required\]/{in_section=1; next} /^\[/{in_section=0} in_section && NF && $0 !~ /^#/ {print}' tools/release-boundary-policy.txt)
  if grep -Eq '^[[:space:]]*\.package\(' Package.swift; then
    fail "SwiftPM dependencies changed; review release notices"
  fi
}

candidate_expected_paths() {
  local roots=()
  local root_path
  while IFS= read -r root_path; do
    roots+=("$root_path")
  done < <(release_candidate_roots)
  git ls-files -- "${roots[@]}"
}

verify_candidate() {
  local candidate="$1"
  [[ -d "$candidate" ]] || fail "release candidate path is not a directory: $candidate"
  candidate="$(cd "$candidate" && pwd -P)"
  for required in LICENSE NOTICE LEGAL.md THIRD_PARTY_NOTICES.md README.md Package.swift Cargo.toml Cargo.lock \
    runtimes/macos/Sources/open-lola runtimes/rust-station/Cargo.toml tools/macos/build_and_run.sh; do
    [[ -e "$candidate/$required" ]] || fail "candidate is missing: $required"
  done
  for excluded in third_party interop archive private internal .agents .codacy \
    runtimes/macos/Tests runtimes/rust-station/tests; do
    [[ ! -e "$candidate/$excluded" ]] || fail "candidate contains excluded path: $excluded"
  done
  local expected_paths
  local actual_paths
  local missing
  local unexpected
  expected_paths="$(candidate_expected_paths | LC_ALL=C sort)"
  actual_paths="$(find "$candidate" -type f -print | sed "s#^$candidate/##" | LC_ALL=C sort)"
  missing="$(comm -23 <(printf '%s\n' "$expected_paths") <(printf '%s\n' "$actual_paths") | sed -n '1p')"
  unexpected="$(comm -13 <(printf '%s\n' "$expected_paths") <(printf '%s\n' "$actual_paths") | sed -n '1p')"
  [[ -z "$missing" ]] || fail "candidate is missing tracked release path: $missing"
  [[ -z "$unexpected" ]] || fail "candidate contains path outside the tracked release allowlist: $unexpected"

  local expected
  while IFS= read -r expected; do
    cmp -s "$expected" "$candidate/$expected" || fail "candidate content differs from source revision: $expected"
  done < <(candidate_expected_paths)

  local forbidden
  forbidden="$(find "$candidate" -mindepth 1 \( \
    -type d \( \
      -name .git -o -name .agent -o -name .agents -o -name .ai -o -name '.aider*' \
      -o -name .claude -o -name .codex -o -name .codegraph -o -name .continue \
      -o -name .cursor -o -name .impeccable -o -name .kilo -o -name .repowise \
      -o -name .serena -o -name .windsurf -o -name .worktrees -o -name worktrees \
      -o -name archive -o -name private -o -name internal -o -name internals \
      -o -name interop -o -name third_party -o -name reverse-engineering \
      -o -name research -o -name Tests -o -name tests -o -name fixtures \
      -o -name __snapshots__ -o -name scripts -o -name reports -o -name artifacts \
      -o -name .build -o -name .swiftpm -o -name target -o -name dist \
      -o -name .cache -o -name .codacy -o -name .pytest_cache -o -name .ruff_cache \
      -o -name .mypy_cache -o -name .venv -o -name venv -o -name __pycache__ \
      -o -name .vscode -o -name .idea -o -name .fleet -o -name .history \
    \) -o \
    -type f \( \
      -name .DS_Store -o -name .mcp.json -o -name .cursorrules \
      -o -name AGENT.md -o -name AGENTS.md -o -name CLAUDE.md -o -name CODEX.md \
      -o -name GEMINI.md -o -name GOAL.md -o -iname 'copilot-instructions.md' \
      -o -name '*.pyc' -o -name '*.pyo' -o -name '*.log' -o -name '*.pcap' \
      -o -name '*.pcapng' -o -name '*.pem' -o -name '*.key' -o -name '*.p12' \
      -o -name '*.pfx' -o -name '*.jks' -o -name '*.keystore' \
      -o -name '*.mobileprovision' -o -name '*.db' -o -name '*.sqlite' \
      -o -name '*.sqlite3' -o -name '*.sarif' -o -name '*.dylib' -o -name '*.so' \
      -o -name '*.dll' -o -name '*.exe' -o -name '*.pkg' -o -name '*.dmg' \
      -o -name credentials.json -o -name secrets.json -o -name auth.json \
      -o -name .env -o \( -name '.env.*' ! -name .env.example \) \
      -o -iname '*TODO*.md' -o -iname '*DRAFT*.md' \
    \) \
  \) -print -quit)"
  [[ -z "$forbidden" ]] || fail "candidate contains excluded artifact: $forbidden"
  echo "RELEASE_HYGIENE_VERDICT: PASS"
}

verify_repository_policy
candidate="${1:-${OPEN_LOLA_RELEASE_CANDIDATE:-}}"
if [[ -n "$candidate" ]]; then
  verify_candidate "$candidate"
else
  echo "RELEASE_HYGIENE_REPOSITORY_VERDICT: PASS"
fi
