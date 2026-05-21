#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/parity.sh
# shellcheck disable=SC1091
source "$script_dir/lib/parity.sh"

open_lola_bin="${OPEN_LOLA_BIN:-.build/debug/open-lola}"
output_dir="$(parity_output_dir "ultragrid-parity-native" "${1:-}")"
native_executable="${OPEN_LOLA_ULTRAGRID_NATIVE_EXECUTABLE:-uv}"
expected_ultragrid_version="${OPEN_LOLA_ULTRAGRID_EXPECTED_VERSION:-UltraGrid 1.10.4}"
peer="${OPEN_LOLA_ULTRAGRID_NATIVE_PEER:-127.0.0.1}"
video_port="${OPEN_LOLA_ULTRAGRID_VIDEO_PORT:-5004}"
audio_port="${OPEN_LOLA_ULTRAGRID_AUDIO_PORT:-5006}"
video_capture="${OPEN_LOLA_ULTRAGRID_VIDEO_CAPTURE:-testcard:640:360:10:RGB}"
audio_capture="${OPEN_LOLA_ULTRAGRID_AUDIO_CAPTURE:-testcard}"
video_display="${OPEN_LOLA_ULTRAGRID_VIDEO_DISPLAY:-dummy}"
audio_playback="${OPEN_LOLA_ULTRAGRID_AUDIO_PLAYBACK:-dummy}"
startup_seconds="${OPEN_LOLA_ULTRAGRID_STARTUP_SECONDS:-4}"
tx_duration_seconds="${OPEN_LOLA_ULTRAGRID_TX_DURATION_SECONDS:-6}"
managed_rx_duration_seconds="${OPEN_LOLA_ULTRAGRID_MANAGED_RX_DURATION_SECONDS:-$((tx_duration_seconds + 2))}"
connection_timeout_seconds="${OPEN_LOLA_ULTRAGRID_CONNECTION_TIMEOUT_SECONDS:-$tx_duration_seconds}"
connection_poll_seconds="${OPEN_LOLA_ULTRAGRID_CONNECTION_POLL_SECONDS:-0.1}"
max_managed_connection_delta_ms="${OPEN_LOLA_ULTRAGRID_MAX_MANAGED_CONNECTION_DELTA_MS:-250}"
max_managed_display_fps_delta="${OPEN_LOLA_ULTRAGRID_MAX_MANAGED_DISPLAY_FPS_DELTA:-0.5}"

direct_dir="$output_dir/direct-ultragrid-native"
managed_dir="$output_dir/open-lola-managed-native"
preflight_report="$output_dir/ultragrid-native-preflight.json"
direct_rx_log="$direct_dir/ultragrid-rx-native.log"
direct_tx_log="$direct_dir/ultragrid-tx-native.log"
managed_rx_report="$managed_dir/ultragrid-rx.json"
managed_tx_report="$managed_dir/ultragrid-tx.json"
managed_connection_metrics="$managed_dir/ultragrid-connection-metrics.json"
metrics_report="$output_dir/ultragrid-native-parity-metrics.json"
direct_rx_pid=""
direct_tx_pid=""
direct_connection_ms=0

mkdir -p "$direct_dir" "$managed_dir"

cleanup() {
  if [[ -n "$direct_tx_pid" ]]; then
    kill "$direct_tx_pid" >/dev/null 2>&1 || true
  fi
  if [[ -n "$direct_rx_pid" ]]; then
    kill "$direct_rx_pid" >/dev/null 2>&1 || true
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

stop_native_process() {
  local pid="$1"

  if kill -0 "$pid" >/dev/null 2>&1; then
    kill -INT "$pid" >/dev/null 2>&1 || true
  fi
  wait "$pid" 2>/dev/null || true
}

"$selected_executable" \
  -d "$video_display" \
  -r "$audio_playback" \
  -t "$video_capture" \
  -s "$audio_capture" \
  -P "$video_port:$video_port:$audio_port:$audio_port" \
  --server >"$direct_rx_log" 2>&1 &
direct_rx_pid=$!

if ! parity_wait_for_file_text "$direct_rx_log" "$startup_seconds" "$connection_poll_seconds" \
  "Audio sending started." \
  "Audio receiving started." \
  "Control socket listening"; then
  echo "Direct native UltraGrid RX did not become ready within ${startup_seconds}s: $direct_rx_log" >&2
  exit 1
fi

direct_tx_started_ms="$(parity_monotonic_ms)"
"$selected_executable" \
  -d "$video_display" \
  -r "$audio_playback" \
  -t "$video_capture" \
  -s "$audio_capture" \
  -P "$video_port:$video_port:$audio_port:$audio_port" \
  --client "$peer" >"$direct_tx_log" 2>&1 &
direct_tx_pid=$!

if parity_wait_for_file_text "$direct_rx_log" "$connection_timeout_seconds" "$connection_poll_seconds" \
  "New incoming audio format detected" \
  "New incoming video format detected"; then
  direct_connection_ms="$(($(parity_monotonic_ms) - direct_tx_started_ms))"
else
  echo "Direct native UltraGrid RX did not receive audio and video within ${connection_timeout_seconds}s: $direct_rx_log" >&2
  exit 1
fi

sleep "$tx_duration_seconds"
stop_native_process "$direct_tx_pid"
direct_tx_pid=""
stop_native_process "$direct_rx_pid"
direct_rx_pid=""

parity_assert_ultragrid_runtime_log "Direct native UltraGrid RX" "$direct_rx_log" "$expected_ultragrid_version" false
parity_assert_ultragrid_runtime_log "Direct native UltraGrid TX" "$direct_tx_log" "$expected_ultragrid_version" false

OPEN_LOLA_BIN="$open_lola_bin" \
OPEN_LOLA_CONNECTOR_DURATION_SECONDS="$managed_rx_duration_seconds" \
OPEN_LOLA_ULTRAGRID_TX_DURATION_SECONDS="$tx_duration_seconds" \
OPEN_LOLA_ULTRAGRID_STARTUP_SECONDS="$startup_seconds" \
OPEN_LOLA_ULTRAGRID_CONNECTION_TIMEOUT_SECONDS="$connection_timeout_seconds" \
OPEN_LOLA_ULTRAGRID_CONNECTION_POLL_SECONDS="$connection_poll_seconds" \
OPEN_LOLA_ULTRAGRID_VIDEO_PORT="$video_port" \
OPEN_LOLA_ULTRAGRID_AUDIO_PORT="$audio_port" \
OPEN_LOLA_ULTRAGRID_NATIVE_EXECUTABLE="$selected_executable" \
OPEN_LOLA_ULTRAGRID_NATIVE_PEER="$peer" \
  bash scripts/run-local-ultragrid-rxtx-native.sh "$managed_dir"

python3 scripts/lib/write-ultragrid-parity-metrics.py \
  --report "$metrics_report" \
  --schema "open-lola-ultragrid-native-parity-metrics-v1" \
  --scope "same-host native direct UltraGrid RX/TX versus Open LoLa-managed native UltraGrid RX/TX" \
  --evidence-boundary "Native same-host packet/decode stability comparison only; not physical route, latency, jitter, or long-run field parity evidence." \
  --direct-label "direct native UltraGrid" \
  --direct-connection-ms "$direct_connection_ms" \
  --managed-connection-metrics "$managed_connection_metrics" \
  --max-managed-connection-delta-ms "$max_managed_connection_delta_ms" \
  --connection-poll-seconds "$connection_poll_seconds" \
  --max-managed-display-fps-delta "$max_managed_display_fps_delta" \
  --video-display "$video_display" \
  --preflight-report "$preflight_report" \
  "direct-rx" "$direct_rx_log" \
  "direct-tx" "$direct_tx_log" \
  "managed-rx" "$managed_rx_report" \
  "managed-tx" "$managed_tx_report"


echo "Native UltraGrid preflight report: $preflight_report"
echo "Direct native UltraGrid RX log: $direct_rx_log"
echo "Direct native UltraGrid TX log: $direct_tx_log"
echo "Open LoLa-managed native UltraGrid RX report: $managed_rx_report"
echo "Open LoLa-managed native UltraGrid TX report: $managed_tx_report"
echo "Native UltraGrid parity metrics: $metrics_report"
echo "VERDICT: PARTIAL"
