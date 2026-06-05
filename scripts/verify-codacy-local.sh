#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROVIDER="${CODACY_PROVIDER:-gh}"
ORGANIZATION="${CODACY_ORG:-sebastianspicker}"
REPOSITORY="${CODACY_REPO:-open-lola-priv}"
INSPECT_OUTPUT="${CODACY_INSPECT_OUTPUT:-/private/tmp/open-lola-codacy-inspect.json}"
ANALYSIS_OUTPUT="${CODACY_LOCAL_OUTPUT:-/private/tmp/open-lola-codacy-analysis.json}"
MODE="full"

usage() {
  cat <<'USAGE'
Usage: bash scripts/verify-codacy-local.sh [--inspect-only] [codacy-analysis analyze options]

Refreshes the local Codacy Analysis CLI configuration from Codacy Cloud,
checks that Cloud-enabled tools are runnable locally, and runs the local
analysis with the same repository exclusions.

Environment:
  CODACY_PROVIDER              Git provider, default: gh
  CODACY_ORG                   Codacy organization, default: sebastianspicker
  CODACY_REPO                  Codacy repository, default: open-lola-priv
  CODACY_INSPECT_OUTPUT        Inspect JSON path, default: /private/tmp/open-lola-codacy-inspect.json
  CODACY_LOCAL_OUTPUT          Analysis JSON path, default: /private/tmp/open-lola-codacy-analysis.json
  CODACY_INSTALL_DEPENDENCIES  Set to 1 to let Codacy install missing tool dependencies.
USAGE
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ "${1:-}" == "--inspect-only" ]]; then
  MODE="inspect"
  shift
fi

require_command() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "Missing required command: $name" >&2
    exit 2
  fi
}

require_command codacy-analysis
require_command jq

mkdir -p "$(dirname "$INSPECT_OUTPUT")" "$(dirname "$ANALYSIS_OUTPUT")"

if [[ -f ".codacy/codacy.config.json" ]]; then
  codacy-analysis update-config
else
  codacy-analysis init --remote "$PROVIDER" "$ORGANIZATION" "$REPOSITORY"
fi

if [[ ! -f ".codacy/codacy.config.json" ]]; then
  echo "Codacy local config was not generated at .codacy/codacy.config.json" >&2
  exit 2
fi

tmp_config="$(mktemp "${TMPDIR:-/tmp}/open-lola-codacy-config.XXXXXX")"
jq '
  def generated_file_under_excluded_tree:
    startswith("archive/") or
    startswith("private/") or
    startswith("Sources/opus-1.5.2/") or
    startswith("Sources/xs_ref_sw_ed2/");
  .exclude = (
    (.exclude // [])
    | map(select((type != "string") or ((generated_file_under_excluded_tree | not) or endswith("/**"))))
    | unique
  )
' ".codacy/codacy.config.json" > "$tmp_config"
mv "$tmp_config" ".codacy/codacy.config.json"

required_excludes=(
  'archive/**'
  'private/**'
  'Sources/opus-1.5.2/**'
  'Sources/xs_ref_sw_ed2/**'
)

for excluded_path in "${required_excludes[@]}"; do
  if ! jq -e --arg path "$excluded_path" '(.exclude // []) | index($path)' ".codacy/codacy.config.json" >/dev/null; then
    echo "Cloud/local Codacy config is missing required exclude: $excluded_path" >&2
    exit 2
  fi
done

install_args=()
if [[ "${CODACY_INSTALL_DEPENDENCIES:-0}" == "1" ]]; then
  install_args+=(--install-dependencies)
else
  install_args+=(--fail-if-missing)
fi

codacy-analysis analyze \
  --inspect \
  --output-format json \
  --output "$INSPECT_OUTPUT" \
  "$@"

unavailable_tools="$(
  jq -r '
    [.capability.unavailable[]? | (.displayName // .toolId)]
    | map(select(. != null))
    | unique
    | .[]
  ' "$INSPECT_OUTPUT"
)"

if [[ -n "$unavailable_tools" ]]; then
  echo "Codacy Cloud has tools enabled that are not runnable locally:" >&2
  echo "$unavailable_tools" >&2
  echo "Install local dependencies with CODACY_INSTALL_DEPENDENCIES=1 or align the Cloud tool configuration." >&2
  exit 1
fi

if [[ "$MODE" == "inspect" ]]; then
  echo "Codacy local inspect passed: $INSPECT_OUTPUT"
  exit 0
fi

codacy-analysis analyze \
  --output-format json \
  --output "$ANALYSIS_OUTPUT" \
  "${install_args[@]}" \
  "$@"

echo "Codacy local analysis written to: $ANALYSIS_OUTPUT"
