#!/usr/bin/env bash
# Share bounded Docker and log helpers used by local media-parity workflows.
set -euo pipefail

parity_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$parity_lib_dir/common.sh"

# Return monotonic milliseconds for timeout calculations unaffected by wall-clock changes.
parity_monotonic_ms() {
  python3 -c '
import time
clock_id = getattr(time, "CLOCK_MONOTONIC", None)
nanoseconds = time.clock_gettime_ns(clock_id) if clock_id is not None else time.monotonic_ns()
print(nanoseconds // 1_000_000)
'
}

# Distinguish a missing or unresponsive Docker daemon from a parity-test failure.
parity_require_docker_daemon() {
  local context="${1:-Docker parity}"
  local timeout_seconds="${OPEN_LOLA_DOCKER_PREFLIGHT_TIMEOUT_SECONDS:-5}"

  python3 - "$context" "$timeout_seconds" <<'PY'
import shutil
import subprocess
import sys

context, timeout_raw = sys.argv[1:]
try:
    timeout_seconds = float(timeout_raw)
except ValueError:
    print(
        f"{context} invalid OPEN_LOLA_DOCKER_PREFLIGHT_TIMEOUT_SECONDS: {timeout_raw}",
        file=sys.stderr,
    )
    sys.exit(64)

if timeout_seconds <= 0:
    print(
        f"{context} invalid OPEN_LOLA_DOCKER_PREFLIGHT_TIMEOUT_SECONDS: {timeout_raw}",
        file=sys.stderr,
    )
    sys.exit(64)

if shutil.which("docker") is None:
    print(f"{context} blocked: docker command not found.", file=sys.stderr)
    sys.exit(77)

try:
    result = subprocess.run(
        ["docker", "ps", "--format", "{{.ID}}"],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        timeout=timeout_seconds,
    )
except subprocess.TimeoutExpired:
    print(
        f"{context} blocked: Docker daemon did not respond within {timeout_raw}s to docker ps.",
        file=sys.stderr,
    )
    print("Start Docker Desktop or the Docker daemon, then rerun this parity check.", file=sys.stderr)
    sys.exit(77)

if result.returncode != 0:
    print(
        f"{context} blocked: Docker daemon preflight failed for docker ps "
        f"(exit {result.returncode}).",
        file=sys.stderr,
    )
    if result.stderr.strip():
        print(result.stderr.strip(), file=sys.stderr)
    sys.exit(77)
PY
}

# Resolve an explicit evidence directory or create a process-specific temporary default.
parity_output_dir() {
  local suffix="$1"
  local explicit_dir="${2:-}"

  if [[ -n "$explicit_dir" ]]; then
    printf '%s\n' "$explicit_dir"
    return
  fi

  printf '%s\n' "${OPEN_LOLA_OUTPUT_DIR:-${TMPDIR:-/tmp}/open-lola-$suffix-$$}"
}

# Run Docker in the foreground while ensuring its named container stops on exit or signal.
parity_run_docker_foreground() {
  parity_docker_foreground_container_name="$1"
  shift

  trap 'docker stop "$parity_docker_foreground_container_name" >/dev/null 2>&1 || true' EXIT
  trap 'docker stop "$parity_docker_foreground_container_name" >/dev/null 2>&1 || true; exit 143' INT TERM

  docker "$@" &
  local docker_pid=$!
  wait "$docker_pid"
}

# Require one literal runtime marker in an evidence log.
parity_require_text() {
  local label="$1"
  local path="$2"
  local expected="$3"

  if ! grep -Fq -- "$expected" "$path"; then
    fail "$label missing expected text '$expected': $path"
  fi
}

# Validate UltraGrid version, media startup, formats, decode statistics, and optional losslessness.
parity_assert_ultragrid_runtime_log() {
  local label="$1"
  local path="$2"
  local expected_version="${3:-UltraGrid 1.10.4}"
  local require_lossless_stats="${4:-true}"

  parity_require_text "$label" "$path" "$expected_version"
  parity_require_text "$label" "$path" "Audio sending started."
  parity_require_text "$label" "$path" "Audio receiving started."
  parity_require_text "$label" "$path" "New incoming audio format detected: 48000 Hz"
  parity_require_text "$label" "$path" "New incoming video format detected: 640x360 @10.00p"
  parity_require_text "$label" "$path" "Audio dec stats (cumulative):"
  parity_require_text "$label" "$path" "Video dec stats (cumulative):"
  if [[ "$require_lossless_stats" == true ]]; then
    parity_require_text "$label" "$path" "100.0000%"
    parity_require_text "$label" "$path" "0 lost"
    parity_require_text "$label" "$path" "0 drop"
    parity_require_text "$label" "$path" "0 miss"
  fi
}

# Return success only when a log exists and contains every requested marker.
parity_file_contains_all() {
  local log_path="$1"
  shift

  [[ -f "$log_path" ]] || return 1
  for expected in "$@"; do
    if ! grep -Fq "$expected" "$log_path"; then
      return 1
    fi
  done
}

# Poll a log until all markers appear or the monotonic deadline expires.
parity_wait_for_file_text() {
  local log_path="$1"
  local timeout_seconds="$2"
  local poll_seconds="$3"
  shift 3
  local started_ms
  local deadline_ms

  started_ms="$(parity_monotonic_ms)"
  deadline_ms=$((started_ms + timeout_seconds * 1000))
  while [[ "$(parity_monotonic_ms)" -le "$deadline_ms" ]]; do
    if parity_file_contains_all "$log_path" "$@"; then
      return 0
    fi
    sleep "$poll_seconds"
  done
  return 1
}

# Save the current log for an existing Docker container to an evidence file.
parity_capture_docker_log() {
  local container_name="$1"
  local log_path="$2"

  command -v docker >/dev/null 2>&1 || fail "docker command not found while capturing log for $container_name"
  docker container inspect "$container_name" >/dev/null 2>&1 || fail "docker container not found while capturing log: $container_name"
  docker logs "$container_name" >"$log_path" 2>&1
}

# Refresh container logs until all readiness markers appear or timeout.
parity_wait_for_docker_log_text() {
  local container_name="$1"
  local log_path="$2"
  local timeout_seconds="$3"
  local poll_seconds="$4"
  shift 4
  local started_ms
  local deadline_ms

  started_ms="$(parity_monotonic_ms)"
  deadline_ms=$((started_ms + timeout_seconds * 1000))
  while [[ "$(parity_monotonic_ms)" -le "$deadline_ms" ]]; do
    parity_capture_docker_log "$container_name" "$log_path"
    if parity_file_contains_all "$log_path" "$@"; then
      return 0
    fi
    sleep "$poll_seconds"
  done
  return 1
}

# Interrupt a container, wait for shutdown, and preserve its final log.
parity_stop_docker_container() {
  local container_name="$1"
  local log_path="$2"

  docker kill --signal=INT "$container_name" >/dev/null 2>&1 || true
  docker wait "$container_name" >/dev/null 2>&1 || true
  parity_capture_docker_log "$container_name" "$log_path"
}

# Stop leftover containers whose names share the parity-run prefix.
parity_stop_docker_containers_by_name_prefix() {
  local name_prefix="$1"

  while read -r container_id; do
    if [[ -n "$container_id" ]]; then
      docker stop "$container_id" >/dev/null 2>&1 || true
    fi
  done < <(docker ps --filter "name=$name_prefix" -q)
}

# Measure JackTrip seconds from receiver startup to peer connection, including midnight rollover.
parity_jacktrip_connection_delay_seconds() {
  local journal_path="$1"

  awk '
    function timestamp_seconds(raw, parts) {
      if (raw !~ /^[0-9][0-9]:[0-9][0-9]:[0-9][0-9](\.[0-9]+)?$/) {
        return -1
      }
      split(raw, parts, "[:.]")
      if (parts[1] > 23 || parts[2] > 59 || parts[3] > 59) {
        return -1
      }
      return parts[1] * 3600 + parts[2] * 60 + parts[3]
    }
    /UDP Socket Receiving in Port:/ && start == "" {
      start = timestamp_seconds($3)
    }
    /Received Connection from Peer!/ && stop == "" {
      stop = timestamp_seconds($3)
    }
    END {
      if (start == "" || stop == "" || start < 0 || stop < 0) {
        exit 1
      }
      delta = stop - start
      if (delta < 0) {
        delta += 86400
      }
      print delta
    }
  ' "$journal_path"
}

# Fail when managed JackTrip setup exceeds the direct baseline by the allowed delta.
parity_require_jacktrip_connection_delay_near_direct() {
  local direct_journal="$1"
  local managed_journal="$2"
  local max_managed_delta_seconds="$3"
  local direct_delay
  local managed_delay
  local maximum_allowed

  direct_delay="$(parity_jacktrip_connection_delay_seconds "$direct_journal")" || {
    fail "Could not parse direct JackTrip connection timestamps: $direct_journal"
  }
  managed_delay="$(parity_jacktrip_connection_delay_seconds "$managed_journal")" || {
    fail "Could not parse managed JackTrip connection timestamps: $managed_journal"
  }
  maximum_allowed=$((direct_delay + max_managed_delta_seconds))

  if ((managed_delay > maximum_allowed)); then
    fail "Open LoLa-managed JackTrip connection delay ${managed_delay}s exceeds direct baseline ${direct_delay}s + ${max_managed_delta_seconds}s: $managed_journal"
  fi

  echo "direct-connection-delay-seconds: $direct_delay"
  echo "managed-connection-delay-seconds: $managed_delay"
  echo "max-managed-delta-seconds: $max_managed_delta_seconds"
}
