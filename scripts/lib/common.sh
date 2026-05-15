#!/usr/bin/env bash
set -euo pipefail

script_name() {
  basename "$0" .sh
}

fail() {
  printf '%s: %s\n' "$(script_name)" "$*" >&2
  exit 1
}

require_file() {
  local path="$1"

  [[ -f "$path" ]] || fail "missing file: $path"
}

require_file_contains() {
  local path="$1"
  local needle="$2"

  grep -Fq -- "$needle" "$path" || fail "$path must contain: $needle"
}
