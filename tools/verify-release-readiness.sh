#!/usr/bin/env bash
# Run source, test, static-analysis, and hygiene gates for the local alpha decision.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
export PYTHONDONTWRITEBYTECODE=1

# shellcheck disable=SC1091
. "$repo_root/tools/lib/common.sh"

tmp_dir="$(mktemp -d)"
release_candidate_path="${OPEN_LOLA_RELEASE_CANDIDATE:-}"
unset OPEN_LOLA_RELEASE_CANDIDATE
OPEN_LOLA_SWIFT_BUILD_PATH="$(open_lola_swift_build_path)"
OPEN_LOLA_TEST_OPEN_LOLA_CLI="${OPEN_LOLA_TEST_OPEN_LOLA_CLI:-}"
export OPEN_LOLA_SWIFT_BUILD_PATH
export OPEN_LOLA_TEST_OPEN_LOLA_CLI
SWIFT_BUILD_TIMEOUT_SECONDS="${SWIFT_BUILD_TIMEOUT_SECONDS:-600}"
SWIFT_TEST_TIMEOUT_SECONDS="${SWIFT_TEST_TIMEOUT_SECONDS:-1800}"
APP_LAUNCH_TIMEOUT_SECONDS="${APP_LAUNCH_TIMEOUT_SECONDS:-180}"
export -n \
  APP_LAUNCH_TIMEOUT_SECONDS \
  OPEN_LOLA_SKIP_INTERACTIVE_APP \
  SWIFT_BUILD_TIMEOUT_SECONDS \
  SWIFT_TEST_TIMEOUT_SECONDS \
  TIMED_STEP_FAILURE_TAIL_LINES
timed_step_index=0

# Remove captured readiness logs and reports when the aggregate gate exits.
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

# Label and execute one mandatory readiness command without masking its status.
run_step() {
  echo "== $* =="
  "$@"
}

# Extract test failures and a bounded log tail from a failed timed command.
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

# Recursively terminate a timed command and any descendants it spawned.
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

# Poll one timed command, reporting its original command and captured evidence on failure.
wait_for_timed_step_or_fail() {
  local pid="$1"
  local deadline="$2"
  local log_file="$3"
  local xunit_file="$4"
  local timeout_seconds="$5"
  shift 5

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

# Run a command with a deadline, captured logs, and optional Swift xUnit evidence.
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
  wait_for_timed_step_or_fail "$pid" "$deadline" "$log_file" "$xunit_file" "$timeout_seconds" "$@"
}

# Report distribution and hardware checks that remain explicitly manual.
manual_hardware_signing_gate() {
  echo "== manual release evidence gates =="
  echo "Developer ID, notarization, Gatekeeper, clean-Mac, hardware, benchmark evidence remain manual gates."
  echo "Release hygiene excludes build output, private material, local archives, blocked fixtures, local LoLa state, and package artifacts from release candidates."
}

# Execute one CLI report command and require its final verdict line.
run_cli_probe() {
  local command_name="$1"
  local expected_verdict="$2"
  local output_file="$tmp_dir/${command_name}.out"

  [[ -x "$OPEN_LOLA_TEST_OPEN_LOLA_CLI" ]] ||
    fail "binary not found at $OPEN_LOLA_TEST_OPEN_LOLA_CLI"
  "$OPEN_LOLA_TEST_OPEN_LOLA_CLI" "$command_name" >"$output_file"

  local last_line
  last_line="$(tail -n 1 "$output_file")"
  if [[ "$last_line" != "VERDICT: $expected_verdict" ]]; then
    fail "$command_name expected VERDICT: $expected_verdict, got: $last_line"
  fi

  echo "$command_name -> $last_line"
}

# Require the final output line to equal the expected verdict.
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

# Require one line matching a regular-expression evidence contract.
require_matching_line() {
  local label="$1"
  local output_file="$2"
  local expected_pattern="$3"
  if ! grep -Eq "$expected_pattern" "$output_file"; then
    fail "$label must match: $expected_pattern"
  fi
}

# Require a nonzero release-blocker count and a matching validator verdict.
run_open_source_release_readiness_probe() {
  local report_path="$tmp_dir/open-source-release-readiness.json"
  local run_output="$tmp_dir/open-source-release-readiness-run.out"
  local validator_output="$tmp_dir/open-source-release-readiness-validator.out"

  "$OPEN_LOLA_TEST_OPEN_LOLA_CLI" \
    open-source-release-readiness-run \
    --output "$report_path" >"$run_output"
  expect_last_verdict "open-source-release-readiness-run" "$run_output" "PARTIAL"
  require_matching_line "open-source-release-readiness-run" "$run_output" "^blockers: [1-9][0-9]*$"

  "$OPEN_LOLA_TEST_OPEN_LOLA_CLI" \
    validate-open-source-release-readiness-report \
    "$report_path" >"$validator_output"
  expect_last_verdict "validate-open-source-release-readiness-report" "$validator_output" "PARTIAL"

  local blocker_line
  blocker_line="$(grep -E '^blockers: [1-9][0-9]*$' "$run_output")"
  echo "open-source-release-readiness-run -> VERDICT: PARTIAL, $blocker_line"
  echo "validate-open-source-release-readiness-report -> VERDICT: PARTIAL"
}

# Build and launch the app, then require process, accessibility, and screenshot evidence.
run_native_app_launch_probe() {
  local evidence_dir="$tmp_dir/native-app-launch-evidence"
  run_timed_step \
    "$APP_LAUNCH_TIMEOUT_SECONDS" \
    env OPEN_LOLA_APP_LAUNCH_EVIDENCE_DIR="$evidence_dir" \
    ./tools/macos/build_and_run.sh --verify
  [[ -s "$evidence_dir/process.pid" ]] || fail "native app launch probe missing process evidence"
  [[ -s "$evidence_dir/accessibility-ui.txt" ]] || fail "native app launch probe missing UI evidence"
  [[ -s "$evidence_dir/screenshot.png" ]] || fail "native app launch probe missing screenshot evidence"
  echo "native app launch probe -> PASS"
}

# Skip interactive launch only when CI explicitly declares a headless environment.
run_native_app_launch_gate() {
  if [[ "${OPEN_LOLA_SKIP_INTERACTIVE_APP:-0}" == "1" ]]; then
    echo "native app launch probe -> SKIPPED (headless CI; run locally for Launch Services and accessibility evidence)"
    return 0
  fi
  run_native_app_launch_probe
}

# Reject synthetic metrics or manual-input placeholders from production Swift sources.
assert_no_production_evidence_placeholders() {
  local matches
  matches="$(
    find runtimes/macos/Sources \
      -type f \
      -name '*.swift' \
      ! -path 'third_party/opus/*' \
      ! -path 'third_party/jpeg-xs/*' \
      -exec grep -HniE 'SyntheticPlaceholderMetrics|todo\(human\)' {} + || true
  )"
  if [[ -n "$matches" ]]; then
    printf '%s\n' "$matches" >&2
    fail "production Sources contain synthetic placeholder metrics or manual todo evidence"
  fi
}

# Run source, static-analysis, test, and release-hygiene gates as one alpha-readiness decision.
main() {
  run_step python3 tools/verify_architecture.py
  run_step bash tools/verify-tracked-boundary.sh
  run_step env PYTHONDONTWRITEBYTECODE=1 bash tools/verify-docs.sh
  run_step env PYTHONDONTWRITEBYTECODE=1 python3 tools/verify_source_documentation.py
  run_step assert_no_production_evidence_placeholders
  run_step shellcheck -x tools/*.sh tools/lib/*.sh tools/macos/*.sh runtimes/linux-compat-connector/linux_connector/deployment/wsl/*.sh
  run_step env RUFF_CACHE_DIR="$tmp_dir/ruff-cache" ruff check runtimes/linux-compat-connector/linux_connector tools/verify_docs tools/lib/*.py tools/verify_source_documentation.py tools/verify_architecture.py
  run_step env PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=runtimes/linux-compat-connector python -m pytest -p no:cacheprovider runtimes/linux-compat-connector/linux_connector
  run_step env MYPY_CACHE_DIR="$tmp_dir/mypy-cache" python -m mypy --strict runtimes/linux-compat-connector/linux_connector/lola_connector tools/verify_docs tools/lib/*.py tools/verify_source_documentation.py tools/verify_architecture.py
  run_step env PYTHONPATH=runtimes/linux-compat-connector python -m linux_connector.lola_connector.cli --local-ip 127.0.0.1 selftest --duration 0.25
  run_step cargo fmt --all -- --check
  run_step cargo clippy --workspace --all-targets --all-features -- -D warnings -D clippy::undocumented_unsafe_blocks -D clippy::missing_safety_doc
  run_step cargo test --workspace --all-targets --all-features
  if [[ -n "$release_candidate_path" ]]; then
    run_step bash tools/verify-release-hygiene.sh "$release_candidate_path"
  else
    run_step bash tools/verify-release-hygiene.sh
  fi
  run_timed_step \
    "$SWIFT_BUILD_TIMEOUT_SECONDS" \
    swift build \
    --disable-sandbox \
    --scratch-path "$OPEN_LOLA_SWIFT_BUILD_PATH"
  run_timed_step \
    "$SWIFT_TEST_TIMEOUT_SECONDS" \
    swift test \
    --disable-sandbox \
    --scratch-path "$OPEN_LOLA_SWIFT_BUILD_PATH"
  OPEN_LOLA_TEST_OPEN_LOLA_CLI="$(open_lola_default_cli_binary)"
  export OPEN_LOLA_TEST_OPEN_LOLA_CLI
  manual_hardware_signing_gate

  echo "== release-readiness CLI probes =="
  run_cli_probe native-app-shell-surface-probe PARTIAL
  run_native_app_launch_gate
  run_open_source_release_readiness_probe

  echo "source-gate-verdict: pass"
  echo "product-runtime-verdict: partial"
  echo "VERDICT: PARTIAL"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
