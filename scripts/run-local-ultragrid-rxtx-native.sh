#!/usr/bin/env bash
# Exercise local bidirectional native UltraGrid transport and record connection metrics.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/parity.sh
# shellcheck disable=SC1091
source "$script_dir/lib/parity.sh"

open_lola_bin="${OPEN_LOLA_BIN:-$(open_lola_default_cli_binary)}"
output_dir="$(parity_output_dir "ultragrid-rxtx-native" "${1:-}")"
native_executable="${OPEN_LOLA_ULTRAGRID_NATIVE_EXECUTABLE:-uv}"
peer="${OPEN_LOLA_ULTRAGRID_NATIVE_PEER:-127.0.0.1}"
rx_duration_seconds="${OPEN_LOLA_CONNECTOR_DURATION_SECONDS:-10}"
tx_duration_seconds="${OPEN_LOLA_ULTRAGRID_TX_DURATION_SECONDS:-6}"
rx_startup_timeout_seconds="${OPEN_LOLA_ULTRAGRID_STARTUP_SECONDS:-4}"
connection_timeout_seconds="${OPEN_LOLA_ULTRAGRID_CONNECTION_TIMEOUT_SECONDS:-$tx_duration_seconds}"
connection_poll_seconds="${OPEN_LOLA_ULTRAGRID_CONNECTION_POLL_SECONDS:-0.1}"
video_port="${OPEN_LOLA_ULTRAGRID_VIDEO_PORT:-5004}"
audio_port="${OPEN_LOLA_ULTRAGRID_AUDIO_PORT:-5006}"
rx_report="$output_dir/ultragrid-rx.json"
tx_report="$output_dir/ultragrid-tx.json"
preflight_report="$output_dir/ultragrid-native-preflight.json"
connection_metrics="$output_dir/ultragrid-connection-metrics.json"
rx_live_log="$output_dir/ultragrid-rx-live-native.log"
tx_live_log="$output_dir/ultragrid-tx-live-native.log"
rx_pid=""
tx_pid=""

mkdir -p "$output_dir"

# Interrupt native UltraGrid processes and wait before the script exits.
cleanup() {
  if [[ -n "$tx_pid" ]]; then
    kill "$tx_pid" >/dev/null 2>&1 || true
  fi
  if [[ -n "$rx_pid" ]]; then
    kill "$rx_pid" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT

"$open_lola_bin" external-connector-executable-preflight-run \
  --connector mvtp-ultragrid \
  --ultragrid-executable "$native_executable" \
  --output "$preflight_report" >/dev/null

selected_executable="$(python3 scripts/lib/extract-preflight-executable.py "$preflight_report")" || {
  echo "Native UltraGrid executable preflight failed: $preflight_report" >&2
  echo "VERDICT: PARTIAL" >&2
  exit 77
}

# Record native managed-connection timing and its source logs as JSON evidence.
write_connection_metrics() {
  local tx_started_ms="$1"
  local connected_ms="$2"
  local elapsed_ms=""
  local connected=false

  if [[ "$connected_ms" -gt 0 ]]; then
    elapsed_ms="$((connected_ms - tx_started_ms))"
    connected=true
  fi

  python3 scripts/lib/write-connection-metrics.py \
    "$connection_metrics" \
    "$connected" \
    "$elapsed_ms" \
    "$connection_timeout_seconds" \
    "$connection_poll_seconds" \
    "$rx_live_log" \
    "$preflight_report" \
    "$selected_executable"
}

# Poll a native process log for one marker until the configured deadline.
wait_for_log_text() {
  local log_path="$1"
  local timeout_seconds="$2"
  shift 2
  local started_ms
  local deadline_ms
  local ready=false

  started_ms="$(parity_monotonic_ms)"
  deadline_ms=$((started_ms + timeout_seconds * 1000))
  while [[ "$(parity_monotonic_ms)" -le "$deadline_ms" ]]; do
    if [[ -f "$log_path" ]]; then
      ready=true
      for expected in "$@"; do
        if ! grep -Fq "$expected" "$log_path"; then
          ready=false
          break
        fi
      done
      if [[ "$ready" == true ]]; then
        return 0
      fi
    fi
    sleep "$connection_poll_seconds"
  done
  return 1
}

# Require incoming audio and video markers before recording managed connection time.
wait_for_managed_connection() {
  local tx_started_ms="$1"
  local connected_ms=0

  if wait_for_log_text "$rx_live_log" "$connection_timeout_seconds" \
    "New incoming audio format detected" \
    "New incoming video format detected"; then
    connected_ms="$(parity_monotonic_ms)"
  fi

  write_connection_metrics "$tx_started_ms" "$connected_ms"

  if [[ "$connected_ms" -eq 0 ]]; then
    echo "Open LoLa-managed native UltraGrid RX did not receive audio and video within ${connection_timeout_seconds}s: $rx_live_log" >&2
    exit 1
  fi
}

OPEN_LOLA_ULTRAGRID_NATIVE_EXECUTABLE="$selected_executable" \
OPEN_LOLA_ULTRAGRID_NATIVE_LOG="$rx_live_log" \
  "$open_lola_bin" external-connector-session-run \
  --connector mvtp-ultragrid \
  --role rx \
  --peer "$peer" \
  --output "$rx_report" \
  --dry-run false \
  --media audio-video \
  --duration-seconds "$rx_duration_seconds" \
  --video-port "$video_port" \
  --audio-port "$audio_port" \
  --video-display dummy \
  --audio-playback dummy \
  --video-capture testcard:640:360:10:RGB \
  --audio-capture testcard \
  --executable scripts/open-lola-ultragrid-native-client.sh &
rx_pid=$!
if ! kill -0 "$rx_pid" >/dev/null 2>&1; then
  echo "Open LoLa-managed native UltraGrid RX process failed to start." >&2
  exit 1
fi
sleep 0.5

if ! wait_for_log_text "$rx_live_log" "$rx_startup_timeout_seconds" \
  "Audio sending started." \
  "Audio receiving started." \
  "Control socket listening"; then
  echo "Open LoLa-managed native UltraGrid RX did not become ready within ${rx_startup_timeout_seconds}s: $rx_live_log" >&2
  exit 1
fi

tx_started_ms="$(parity_monotonic_ms)"
OPEN_LOLA_ULTRAGRID_NATIVE_EXECUTABLE="$selected_executable" \
OPEN_LOLA_ULTRAGRID_NATIVE_LOG="$tx_live_log" \
  "$open_lola_bin" external-connector-session-run \
  --connector mvtp-ultragrid \
  --role tx \
  --peer "$peer" \
  --output "$tx_report" \
  --dry-run false \
  --media audio-video \
  --duration-seconds "$tx_duration_seconds" \
  --video-port "$video_port" \
  --audio-port "$audio_port" \
  --video-display dummy \
  --audio-playback dummy \
  --video-capture testcard:640:360:10:RGB \
  --audio-capture testcard \
  --executable scripts/open-lola-ultragrid-native-client.sh &
tx_pid=$!

wait_for_managed_connection "$tx_started_ms"
wait "$tx_pid"
tx_pid=""

wait "$rx_pid"
rx_pid=""

"$open_lola_bin" validate-external-connector-session-report "$rx_report"
"$open_lola_bin" validate-external-connector-session-report "$tx_report"

echo "Native UltraGrid preflight report: $preflight_report"
echo "Native UltraGrid RX report: $rx_report"
echo "Native UltraGrid TX report: $tx_report"
echo "Native UltraGrid connection metrics: $connection_metrics"
echo "VERDICT: PARTIAL"
