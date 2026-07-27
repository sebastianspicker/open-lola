#!/usr/bin/env bash
# Shared shell helpers keep release checks consistent and diagnostic.
set -euo pipefail

# Derive a stable command label for shared failure messages.
script_name() {
  basename "$0" .sh
}

# Print a script-prefixed diagnostic to stderr and terminate with status 1.
fail() {
  printf '%s: %s\n' "$(script_name)" "$*" >&2
  exit 1
}

# Fail immediately when a required repository file is absent.
require_file() {
  local path="$1"

  [[ -f "$path" ]] || fail "missing file: $path"
}

# Require one literal contract marker inside a repository file.
require_file_contains() {
  local path="$1"
  local needle="$2"

  grep -Fq -- "$needle" "$path" || fail "$path must contain: $needle"
}

# Return the caller-selected Swift scratch path or the repository's temporary default.
open_lola_swift_build_path() {
  printf '%s\n' "${OPEN_LOLA_SWIFT_BUILD_PATH:-/private/tmp/open-lola-swiftpm-build}"
}

# Return the caller-selected CLI path or the debug binary under the Swift scratch path.
open_lola_default_cli_binary() {
  local build_path
  build_path="$(open_lola_swift_build_path)"
  printf '%s\n' "${OPEN_LOLA_TEST_OPEN_LOLA_CLI:-$build_path/debug/open-lola}"
}

# Extract the COpus C-source list directly from Package.swift for vendor-boundary checks.
package_copus_sources() {
  local package_path="$1"

  require_file "$package_path"
  awk '
    /name:[[:space:]]*"COpus"/ { in_target = 1 }
    in_target && /sources:[[:space:]]*\[/ { in_sources = 1; next }
    in_sources && /^[[:space:]]*\],[[:space:]]*$/ { exit }
    in_sources {
      line = $0
      sub(/^[^"]*"/, "", line)
      sub(/".*$/, "", line)
      if (line ~ /\.c$/) print line
    }
  ' "$package_path"
}
