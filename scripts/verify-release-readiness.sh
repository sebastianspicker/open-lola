#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

# shellcheck disable=SC1091
. "$repo_root/scripts/lib/common.sh"

tmp_dir="$(mktemp -d)"
SWIFT_BUILD_TIMEOUT_SECONDS="${SWIFT_BUILD_TIMEOUT_SECONDS:-600}"
SWIFT_TEST_TIMEOUT_SECONDS="${SWIFT_TEST_TIMEOUT_SECONDS:-1800}"
APP_LAUNCH_TIMEOUT_SECONDS="${APP_LAUNCH_TIMEOUT_SECONDS:-180}"
timed_step_index=0

cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

run_step() {
  echo "== $* =="
  "$@"
}

print_timed_step_failure_log() {
  local log_file="$1"
  local xunit_file="${2:-}"
  local failure_matches
  failure_matches="$(
    grep -En \
      'recorded an issue|Expectation failed|Caught error|failed after .* issue|Test run with .* failed' \
      "$log_file" || true
  )"
  if [[ -n "$failure_matches" ]]; then
    echo "== timed step failure matches ==" >&2
    printf '%s\n' "$failure_matches" >&2
  fi
  if [[ -n "$xunit_file" && -s "$xunit_file" ]]; then
    echo "== timed step xUnit failures ==" >&2
    python3 - "$xunit_file" <<'PY' >&2 || true
import sys
import xml.etree.ElementTree as ET

tree = ET.parse(sys.argv[1])
for case in tree.iter("testcase"):
    failures = list(case.iter("failure")) + list(case.iter("error"))
    if not failures:
        continue
    name = case.attrib.get("name", "<unknown>")
    classname = case.attrib.get("classname", "")
    print(f"{classname}.{name}".strip("."))
    for failure in failures:
        text = (failure.text or failure.attrib.get("message") or "").strip()
        if text:
            print(text[:2000])
PY
  fi
  echo "== timed step log tail ==" >&2
  tail -n "${TIMED_STEP_FAILURE_TAIL_LINES:-240}" "$log_file" >&2 || true
}

kill_process_tree() {
  local pid="$1"
  local child
  while IFS= read -r child; do
    if [[ -n "$child" ]]; then
      kill_process_tree "$child"
    fi
  done < <(pgrep -P "$pid" 2>/dev/null || true)
  kill -TERM "$pid" 2>/dev/null || true
}

run_timed_step() {
  local timeout_seconds="$1"
  shift
  timed_step_index=$((timed_step_index + 1))
  local log_file="$tmp_dir/timed-step-${timed_step_index}.log"
  local xunit_file="$tmp_dir/timed-step-${timed_step_index}.xunit.xml"
  local command_args=("$@")
  if [[ "$1" == "swift" && "${2:-}" == "test" ]]; then
    command_args+=("--xunit-output" "$xunit_file")
  fi
  echo "== timeout ${timeout_seconds}s: $* =="
  : >"$log_file" || fail "timed step log file is not writable: $log_file"
  [[ -w "$log_file" ]] || fail "timed step log file is not writable: $log_file"
  "${command_args[@]}" >"$log_file" 2>&1 &
  local pid="$!"
  local deadline=$((SECONDS + timeout_seconds))
  while kill -0 "$pid" 2>/dev/null; do
    if (( SECONDS >= deadline )); then
      kill_process_tree "$pid"
      wait "$pid" 2>/dev/null || true
      print_timed_step_failure_log "$log_file" "$xunit_file"
      fail "$* timed out after ${timeout_seconds}s"
    fi
    sleep 1
  done
  local status=0
  wait "$pid" || status="$?"
  if (( status != 0 )); then
    print_timed_step_failure_log "$log_file" "$xunit_file"
    return "$status"
  fi
  echo "completed: $*"
}

manual_hardware_signing_gate() {
  echo "== manual release evidence gates =="
  echo "Developer ID, notarization, Gatekeeper, clean-Mac, hardware, benchmark evidence remain manual gates."
  echo "C12 release hygiene gate excludes .build/ win-compiled/ private/ reverse-engineering/ archive/ plus blocked fixtures, local LoLa state, and package artifacts from release candidates."
}

run_cli_probe() {
  local command_name="$1"
  local expected_verdict="$2"
  local cli_binary=".build/debug/open-lola"
  local output_file="$tmp_dir/${command_name}.out"

  [[ -x "$cli_binary" ]] || fail "binary not found at $cli_binary"
  "$cli_binary" "$command_name" >"$output_file"

  local last_line
  last_line="$(tail -n 1 "$output_file")"
  if [[ "$last_line" != "VERDICT: $expected_verdict" ]]; then
    fail "$command_name expected VERDICT: $expected_verdict, got: $last_line"
  fi

  echo "$command_name -> $last_line"
}

expect_last_verdict() {
  local label="$1"
  local output_file="$2"
  local expected_verdict="$3"
  local last_line
  last_line="$(tail -n 1 "$output_file")"
  if [[ "$last_line" != "VERDICT: $expected_verdict" ]]; then
    fail "$label expected VERDICT: $expected_verdict, got: $last_line"
  fi
}

require_exact_line() {
  local label="$1"
  local output_file="$2"
  local expected="$3"
  if ! grep -qx "$expected" "$output_file"; then
    fail "$label must include: $expected"
  fi
}

require_matching_line() {
  local label="$1"
  local output_file="$2"
  local expected_pattern="$3"
  if ! grep -Eq "$expected_pattern" "$output_file"; then
    fail "$label must match: $expected_pattern"
  fi
}

run_goal_report_probe() {
  local command_name="$1"
  local run_command="$2"
  local validator_command="$3"
  local expected_verdict="$4"
  local blocker_pattern="${5:-}"
  local output_file="$tmp_dir/${command_name}.out"
  local report_path="$tmp_dir/${command_name}.json"
  local run_output="$tmp_dir/${run_command}.out"
  local validator_output="$tmp_dir/${validator_command}.out"

  ".build/debug/open-lola" "$command_name" >"$output_file"
  expect_last_verdict "$command_name" "$output_file" "$expected_verdict"
  require_exact_line "$command_name" "$output_file" "real-world-verdict: partial"
  if [[ -n "$blocker_pattern" ]]; then
    require_matching_line "$command_name" "$output_file" "$blocker_pattern"
  fi

  ".build/debug/open-lola" "$run_command" --output "$report_path" >"$run_output"
  expect_last_verdict "$run_command" "$run_output" "$expected_verdict"

  ".build/debug/open-lola" "$validator_command" "$report_path" >"$validator_output"
  expect_last_verdict "$validator_command" "$validator_output" "$expected_verdict"
  require_exact_line "$validator_command" "$validator_output" "real-world-verdict: partial"
  if [[ -n "$blocker_pattern" ]]; then
    require_matching_line "$validator_command" "$validator_output" "$blocker_pattern"
  fi

  echo "$command_name -> VERDICT: $expected_verdict, real-world-verdict: partial"
  echo "$validator_command -> VERDICT: $expected_verdict, real-world-verdict: partial"
}

run_open_source_release_readiness_probe() {
  local report_path="$tmp_dir/open-source-release-readiness.json"
  local run_output="$tmp_dir/open-source-release-readiness-run.out"
  local validator_output="$tmp_dir/open-source-release-readiness-validator.out"

  ".build/debug/open-lola" open-source-release-readiness-run --output "$report_path" >"$run_output"
  expect_last_verdict "open-source-release-readiness-run" "$run_output" "PARTIAL"
  require_exact_line "open-source-release-readiness-run" "$run_output" "blockers: 6"

  ".build/debug/open-lola" validate-open-source-release-readiness-report "$report_path" >"$validator_output"
  expect_last_verdict "validate-open-source-release-readiness-report" "$validator_output" "PARTIAL"

  echo "open-source-release-readiness-run -> VERDICT: PARTIAL, blockers: 6"
  echo "validate-open-source-release-readiness-report -> VERDICT: PARTIAL"
}

run_native_app_launch_probe() {
  local evidence_dir="$tmp_dir/native-app-launch-evidence"
  run_timed_step \
    "$APP_LAUNCH_TIMEOUT_SECONDS" \
    env OPEN_LOLA_APP_LAUNCH_EVIDENCE_DIR="$evidence_dir" \
    ./script/build_and_run.sh --verify
  [[ -s "$evidence_dir/process.pid" ]] || fail "native app launch probe missing process evidence"
  [[ -s "$evidence_dir/accessibility-ui.txt" ]] || fail "native app launch probe missing UI evidence"
  [[ -s "$evidence_dir/screenshot.png" ]] || fail "native app launch probe missing screenshot evidence"
  echo "native app launch probe -> PASS"
}

assert_no_production_evidence_placeholders() {
  local matches
  matches="$(
    find Sources \
      -type f \
      -name '*.swift' \
      ! -path 'Sources/opus-1.5.2/*' \
      ! -path 'Sources/xs_ref_sw_ed2/*' \
      -exec grep -HniE 'SyntheticPlaceholderMetrics|todo\(human\)' {} + || true
  )"
  if [[ -n "$matches" ]]; then
    printf '%s\n' "$matches" >&2
    fail "production Sources contain synthetic placeholder metrics or manual todo evidence"
  fi
}

main() {
  run_step env PYTHONDONTWRITEBYTECODE=1 bash scripts/verify-docs.sh
  run_step assert_no_production_evidence_placeholders
  run_step shellcheck -x scripts/*.sh scripts/lib/*.sh script/*.sh linux_connector/env/*.sh
  run_step env RUFF_CACHE_DIR="$tmp_dir/ruff-cache" ruff check linux_connector scripts/verify_docs scripts/lib/*.py
  run_step env PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector
  run_step env MYPY_CACHE_DIR="$tmp_dir/mypy-cache" python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py
  run_step bash scripts/verify-release-hygiene.sh
  run_timed_step "$SWIFT_BUILD_TIMEOUT_SECONDS" swift build
  run_timed_step "$SWIFT_TEST_TIMEOUT_SECONDS" swift test --no-parallel

  manual_hardware_signing_gate

  echo "== release-readiness CLI probes =="
  run_cli_probe command-inventory PARTIAL
  run_cli_probe source-ownership-inventory PARTIAL
  run_cli_probe fixture-smoke-matrix PARTIAL
  run_cli_probe report-schema-inventory PARTIAL
  run_goal_report_probe \
    goal-codewise-closure \
    goal-codewise-closure-run \
    validate-goal-codewise-closure-report \
    PASS
  run_cli_probe realtime-audio-path-inventory PARTIAL
  run_cli_probe network-route-command-matrix PARTIAL
  run_cli_probe video-control-degrade-matrix PARTIAL
  run_cli_probe native-app-shell-surface-probe PARTIAL
  run_native_app_launch_probe
  run_goal_report_probe \
    goal-runtime-evidence-template \
    goal-runtime-evidence-template-run \
    validate-goal-runtime-evidence-template-report \
    PARTIAL
  run_goal_report_probe \
    goal-runtime-preflight \
    goal-runtime-preflight-run \
    validate-goal-runtime-preflight-report \
    PARTIAL
  run_goal_report_probe \
    goal-completion-audit \
    goal-completion-audit-run \
    validate-goal-completion-audit-report \
    PARTIAL \
    "^blockers: [1-9][0-9]*$"
  run_open_source_release_readiness_probe

  echo "source-gate-verdict: pass"
  echo "product-runtime-verdict: partial"
  echo "VERDICT: PARTIAL"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
