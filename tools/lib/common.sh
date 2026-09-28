#!/usr/bin/env bash
# Shared shell helpers for source packaging checks.
set -euo pipefail

script_name() {
  basename "$0" .sh
}

fail() {
  printf '%s: %s\n' "$(script_name)" "$*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || fail "missing file: $1"
}

require_file_contains() {
  local path="$1"
  local needle="$2"
  grep -Fq -- "$needle" "$path" || fail "$path must contain: $needle"
}

release_candidate_roots() {
  printf '%s\n' \
    ".github" ".gitattributes" ".gitignore" "Cargo.toml" "Cargo.lock" \
    "Makefile" "Package.swift" "LICENSE" "NOTICE" "LEGAL.md" \
    "THIRD_PARTY_NOTICES.md" "README.md" "CONTRIBUTING.md" "SECURITY.md" \
    "CODE_OF_CONDUCT.md" "SUPPORT.md" "CHANGELOG.md" \
    "runtimes" "tools" "web" "docs"
}
