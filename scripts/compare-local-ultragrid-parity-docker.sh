#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/parity.sh
# shellcheck disable=SC1091
source "$script_dir/lib/parity.sh"
# shellcheck source=scripts/open-lola-ultragrid-docker-policy.sh
# shellcheck disable=SC1091
source "$script_dir/open-lola-ultragrid-docker-policy.sh"

open_lola_bin="${OPEN_LOLA_BIN:-.build/debug/open-lola}"
output_dir="$(parity_output_dir "ultragrid-parity" "${1:-}")"
image="$(open_lola_required_ultragrid_docker_image)"
expected_ultragrid_version="${OPEN_LOLA_ULTRAGRID_EXPECTED_VERSION:-UltraGrid 1.10.4}"
video_port="${OPEN_LOLA_ULTRAGRID_VIDEO_PORT:-5004}"
audio_port="${OPEN_LOLA_ULTRAGRID_AUDIO_PORT:-5006}"
video_capture="${OPEN_LOLA_ULTRAGRID_VIDEO_CAPTURE:-testcard:640:360:10:RGB}"
audio_capture="${OPEN_LOLA_ULTRAGRID_AUDIO_CAPTURE:-testcard}"
video_display="${OPEN_LOLA_ULTRAGRID_VIDEO_DISPLAY:-dummy}"
audio_playback="${OPEN_LOLA_ULTRAGRID_AUDIO_PLAYBACK:-dummy}"
startup_seconds="${OPEN_LOLA_ULTRAGRID_STARTUP_SECONDS:-4}"
tx_duration_seconds="${OPEN_LOLA_ULTRAGRID_TX_DURATION_SECONDS:-8}"
managed_rx_duration_seconds="${OPEN_LOLA_ULTRAGRID_MANAGED_RX_DURATION_SECONDS:-$((tx_duration_seconds + 2))}"
connection_timeout_seconds="${OPEN_LOLA_ULTRAGRID_CONNECTION_TIMEOUT_SECONDS:-$tx_duration_seconds}"
connection_poll_seconds="${OPEN_LOLA_ULTRAGRID_CONNECTION_POLL_SECONDS:-0.1}"
max_managed_connection_delta_ms="${OPEN_LOLA_ULTRAGRID_MAX_MANAGED_CONNECTION_DELTA_MS:-250}"
max_managed_display_fps_delta="${OPEN_LOLA_ULTRAGRID_MAX_MANAGED_DISPLAY_FPS_DELTA:-0.5}"

prefix="open-lola-ultragrid-parity-$$"
network_name="$prefix-net"
direct_rx_name="$prefix-direct-rx"
direct_tx_name="$prefix-direct-tx"
direct_dir="$output_dir/direct-ultragrid"
managed_dir="$output_dir/open-lola-managed"
direct_rx_log="$direct_dir/ultragrid-rx-docker.log"
direct_tx_log="$direct_dir/ultragrid-tx-docker.log"
managed_rx_report="$managed_dir/ultragrid-rx.json"
managed_tx_report="$managed_dir/ultragrid-tx.json"
managed_connection_metrics="$managed_dir/ultragrid-connection-metrics.json"
metrics_report="$output_dir/ultragrid-parity-metrics.json"
direct_connection_ms=0

mkdir -p "$direct_dir" "$managed_dir"

parity_require_docker_daemon "UltraGrid Docker parity"

if ! docker image inspect "$image" >/dev/null 2>&1; then
  bash scripts/build-local-ultragrid-docker.sh
fi

cleanup() {
  docker rm -f "$direct_tx_name" "$direct_rx_name" >/dev/null 2>&1 || true
  docker network rm "$network_name" >/dev/null 2>&1 || true
}

trap cleanup EXIT

run_direct_container() {
  local name="$1"
  local publish_ports="${2:-false}"
  shift 2
  local docker_args=(
    run
    --detach
    --name "$name"
    --network "$network_name"
    --add-host host.docker.internal:host-gateway
  )

  if [[ "$publish_ports" == true ]]; then
    docker_args+=(
      -p "$video_port:$video_port/udp"
      -p "$audio_port:$audio_port/udp"
    )
  fi

  docker_args+=("$image")
  docker_args+=("$@")
  docker "${docker_args[@]}" >/dev/null
}

stop_direct_container() {
  local container_name="$1"
  local log_path="$2"

  parity_stop_docker_container "$container_name" "$log_path"
}

require_direct_connection() {
  local tx_started_ms="$1"

  if parity_wait_for_docker_log_text \
    "$direct_rx_name" \
    "$direct_rx_log" \
    "$connection_timeout_seconds" \
    "$connection_poll_seconds" \
    "New incoming audio format detected" \
    "New incoming video format detected"; then
    direct_connection_ms="$(($(parity_monotonic_ms) - tx_started_ms))"
  else
    echo "Direct UltraGrid RX did not receive audio and video within ${connection_timeout_seconds}s: $direct_rx_log" >&2
    exit 1
  fi
}

require_direct_rx_ready() {
  local _started_ms="$1"

  if ! parity_wait_for_docker_log_text \
    "$direct_rx_name" \
    "$direct_rx_log" \
    "$startup_seconds" \
    "$connection_poll_seconds" \
    "Audio sending started." \
    "Audio receiving started." \
    "Control socket listening"; then
    echo "Direct UltraGrid RX did not become ready within ${startup_seconds}s: $direct_rx_log" >&2
    exit 1
  fi
}

assert_managed_report_arguments() {
  parity_require_text "Open LoLa-managed UltraGrid RX" "$managed_rx_report" '"-d"'
  parity_require_text "Open LoLa-managed UltraGrid RX" "$managed_rx_report" "\"$video_display\""
  parity_require_text "Open LoLa-managed UltraGrid RX" "$managed_rx_report" '"-r"'
  parity_require_text "Open LoLa-managed UltraGrid RX" "$managed_rx_report" "\"$audio_playback\""
  parity_require_text "Open LoLa-managed UltraGrid RX" "$managed_rx_report" '"-t"'
  parity_require_text "Open LoLa-managed UltraGrid RX" "$managed_rx_report" "$video_capture"
  parity_require_text "Open LoLa-managed UltraGrid RX" "$managed_rx_report" '"-s"'
  parity_require_text "Open LoLa-managed UltraGrid RX" "$managed_rx_report" "\"$audio_capture\""
  parity_require_text "Open LoLa-managed UltraGrid RX" "$managed_rx_report" '"-P"'
  parity_require_text "Open LoLa-managed UltraGrid RX" "$managed_rx_report" "\"$video_port:$video_port:$audio_port:$audio_port\""
}

write_metric_report() {
  python3 scripts/lib/write-ultragrid-parity-metrics.py \
    --report "$metrics_report" \
    --schema "open-lola-ultragrid-local-parity-metrics-v1" \
    --scope "same-host Docker direct UltraGrid RX/TX versus Open LoLa-managed UltraGrid RX/TX" \
    --evidence-boundary "Local Docker packet/decode stability comparison only; not physical route, native device, latency, jitter, or long-run field parity evidence." \
    --direct-label "direct UltraGrid" \
    --direct-connection-ms "$direct_connection_ms" \
    --managed-connection-metrics "$managed_connection_metrics" \
    --max-managed-connection-delta-ms "$max_managed_connection_delta_ms" \
    --connection-poll-seconds "$connection_poll_seconds" \
    --max-managed-display-fps-delta "$max_managed_display_fps_delta" \
    --video-display "$video_display" \
    "direct-rx" "$direct_rx_log" \
    "direct-tx" "$direct_tx_log" \
    "managed-rx" "$managed_rx_report" \
    "managed-tx" "$managed_tx_report"
}

docker network create "$network_name" >/dev/null

run_direct_container \
  "$direct_rx_name" \
  true \
  -d "$video_display" \
  -r "$audio_playback" \
  -t "$video_capture" \
  -s "$audio_capture" \
  -P "$video_port:$video_port:$audio_port:$audio_port" \
  --server

direct_rx_started_ms="$(parity_monotonic_ms)"
require_direct_rx_ready "$direct_rx_started_ms"

direct_tx_started_ms="$(parity_monotonic_ms)"
run_direct_container \
  "$direct_tx_name" \
  false \
  -d "$video_display" \
  -r "$audio_playback" \
  -t "$video_capture" \
  -s "$audio_capture" \
  -P "$video_port:$video_port:$audio_port:$audio_port" \
  --client host.docker.internal

require_direct_connection "$direct_tx_started_ms"
sleep "$tx_duration_seconds"
stop_direct_container "$direct_tx_name" "$direct_tx_log"
stop_direct_container "$direct_rx_name" "$direct_rx_log"
parity_assert_ultragrid_runtime_log "Direct UltraGrid RX" "$direct_rx_log" "$expected_ultragrid_version"
parity_assert_ultragrid_runtime_log "Direct UltraGrid TX" "$direct_tx_log" "$expected_ultragrid_version"
docker rm -f "$direct_tx_name" "$direct_rx_name" >/dev/null 2>&1 || true

OPEN_LOLA_BIN="$open_lola_bin" \
OPEN_LOLA_CONNECTOR_DURATION_SECONDS="$managed_rx_duration_seconds" \
OPEN_LOLA_ULTRAGRID_TX_DURATION_SECONDS="$tx_duration_seconds" \
OPEN_LOLA_ULTRAGRID_STARTUP_SECONDS="$startup_seconds" \
OPEN_LOLA_ULTRAGRID_CONNECTION_TIMEOUT_SECONDS="$connection_timeout_seconds" \
OPEN_LOLA_ULTRAGRID_CONNECTION_POLL_SECONDS="$connection_poll_seconds" \
OPEN_LOLA_ULTRAGRID_VIDEO_PORT="$video_port" \
OPEN_LOLA_ULTRAGRID_AUDIO_PORT="$audio_port" \
OPEN_LOLA_ULTRAGRID_DOCKER_IMAGE="$image" \
  bash scripts/run-local-ultragrid-rxtx-docker.sh "$managed_dir"

parity_assert_ultragrid_runtime_log "Open LoLa-managed UltraGrid RX" "$managed_rx_report" "$expected_ultragrid_version"
parity_assert_ultragrid_runtime_log "Open LoLa-managed UltraGrid TX" "$managed_tx_report" "$expected_ultragrid_version"
assert_managed_report_arguments
write_metric_report

echo "Direct UltraGrid RX log: $direct_rx_log"
echo "Direct UltraGrid TX log: $direct_tx_log"
echo "Open LoLa-managed UltraGrid RX report: $managed_rx_report"
echo "Open LoLa-managed UltraGrid TX report: $managed_tx_report"
echo "UltraGrid local parity metrics: $metrics_report"
echo "connection-timeout-seconds: $connection_timeout_seconds"
echo "connection-poll-seconds: $connection_poll_seconds"
echo "max-managed-connection-delta-ms: $max_managed_connection_delta_ms"
echo "max-managed-display-fps-delta: $max_managed_display_fps_delta"
echo "managed-rx-duration-seconds: $managed_rx_duration_seconds"
echo "VERDICT: PARTIAL"
