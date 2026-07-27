#!/usr/bin/env bash
# Verify tracked-boundary before a local alpha release is declared ready.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf '%s\n' "Tracked-boundary verification requires a Git worktree." >&2
  exit 1
fi

violation_count=0
private_internal_count=0
agent_count=0
archive_count=0
workflow_document_count=0
sensitive_artifact_count=0
generated_state_count=0

if ! tracked_paths="$(git ls-files)"; then
  printf '%s\n' "Tracked-boundary verification could not read the Git index." >&2
  exit 1
fi

# Return whether a path is a known local workflow or instruction document.
is_tracking_document() {
  case "$1" in
    *.md|*.markdown|*.rst|*.txt|*.json|*.yaml|*.yml|*.sarif)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Return whether a basename matches the local tracking-document naming policy.
is_local_tracking_name() {
  local path="$1"
  local basename
  basename="$(basename "$path" | tr '[:upper:]' '[:lower:]')"
  case "$basename" in
    *audit*|*remediation*|*ledger*|plan.*|plan-*|*-plan.*|*-plan-*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

while IFS= read -r path; do
  case "$path" in
    private/*|internal/*|internals/*|docs/local/*|docs/internal/*|reverse-engineering/*|research/*|win-compiled/*|mac-port/*|docs/review/*)
      violation_count=$((violation_count + 1))
      private_internal_count=$((private_internal_count + 1))
      continue
      ;;
    .agents/*|.claude/*|.codex/*|.codegraph/*|.cursor/*|.impeccable/*|.serena/*|docs/agent/*|docs/agents/*)
      violation_count=$((violation_count + 1))
      agent_count=$((agent_count + 1))
      continue
      ;;
    AGENTS.md|*/AGENTS.md|CLAUDE.md|*/CLAUDE.md|GEMINI.md|*/GEMINI.md|.github/copilot-instructions.md)
      violation_count=$((violation_count + 1))
      agent_count=$((agent_count + 1))
      continue
      ;;
    archive/*)
      if [[ "$path" != "archive/README.md" ]]; then
        violation_count=$((violation_count + 1))
        archive_count=$((archive_count + 1))
      fi
      continue
      ;;
    docs/implementation-handoff.md|docs/archive-binary-retention-proposal.md|scripts/verify_docs/archive_topology.txt)
      violation_count=$((violation_count + 1))
      workflow_document_count=$((workflow_document_count + 1))
      continue
      ;;
    reports/*|artifacts/*|*.key|*.pem|*.p12|*.pfx|*.jks|*.keystore|*.mobileprovision|credentials.json|*/credentials.json|secrets.json|*/secrets.json|auth.json|*/auth.json|*.db|*.db-shm|*.db-wal|*.sqlite|*.sqlite3|*.sarif)
      violation_count=$((violation_count + 1))
      sensitive_artifact_count=$((sensitive_artifact_count + 1))
      continue
      ;;
    .build/*|.swiftpm/*|DerivedData/*|build/*|dist/*|local/*|tmp/*|scratch/*|out/*|re_out/*|coverage/*|.cache/*|.codacy/*|.pytest_cache/*|.ruff_cache/*|.mypy_cache/*|.hypothesis/*|.tox/*|.nox/*|.venv/*|venv/*|.uv-cache/*|*.egg-info/*|pip-wheel-metadata/*|.vscode/*|.idea/*|.fleet/*|.history/*|__pycache__/*|*/__pycache__/*)
      violation_count=$((violation_count + 1))
      generated_state_count=$((generated_state_count + 1))
      continue
      ;;
  esac

  if [[ "$path" != */* || "$path" == docs/* ]]; then
    if is_tracking_document "$path" && is_local_tracking_name "$path"; then
      violation_count=$((violation_count + 1))
      workflow_document_count=$((workflow_document_count + 1))
    fi
  fi
done <<<"$tracked_paths"

if (( violation_count > 0 )); then
  printf '%s\n' "Tracked-boundary verification failed; local-only files remain tracked." >&2
  printf '  private/internal: %d\n' "$private_internal_count" >&2
  printf '  local tool state: %d\n' "$agent_count" >&2
  printf '  archive payload: %d\n' "$archive_count" >&2
  printf '  workflow documents: %d\n' "$workflow_document_count" >&2
  printf '  sensitive/generated artifacts: %d\n' "$sensitive_artifact_count" >&2
  printf '  generated/tool/editor state: %d\n' "$generated_state_count" >&2
  printf '  total: %d\n' "$violation_count" >&2
  exit 1
fi

echo "TRACKED_BOUNDARY_VERDICT: PASS"
