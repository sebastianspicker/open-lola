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
output_dir="${1:-${OPEN_LOLA_OUTPUT_DIR:-${TMPDIR:-/tmp}/open-lola-ultragrid-rxtx-$$}}"
rx_duration_seconds="${OPEN_LOLA_CONNECTOR_DURATION_SECONDS:-12}"
tx_duration_seconds="${OPEN_LOLA_ULTRAGRID_TX_DURATION_SECONDS:-8}"
rx_startup_timeout_seconds="${OPEN_LOLA_ULTRAGRID_STARTUP_SECONDS:-4}"
image="$(open_lola_required_ultragrid_docker_image)"
video_port="${OPEN_LOLA_ULTRAGRID_VIDEO_PORT:-5004}"
audio_port="${OPEN_LOLA_ULTRAGRID_AUDIO_PORT:-5006}"
connection_timeout_seconds="${OPEN_LOLA_ULTRAGRID_CONNECTION_TIMEOUT_SECONDS:-$tx_duration_seconds}"
connection_poll_seconds="${OPEN_LOLA_ULTRAGRID_CONNECTION_POLL_SECONDS:-0.1}"
rx_report="$output_dir/ultragrid-rx.json"
tx_report="$output_dir/ultragrid-tx.json"
connection_metrics="$output_dir/ultragrid-connection-metrics.json"
managed_rx_live_log="$output_dir/ultragrid-rx-live-docker.log"

mkdir -p "$output_dir"

if ! docker image inspect "$image" >/dev/null 2>&1; then
  bash scripts/build-local-ultragrid-docker.sh
fi

cleanup() {
  while read -r container_id; do
    if [[ -n "$container_id" ]]; then
      docker stop "$container_id" >/dev/null 2>&1 || true
    fi
  done < <(docker ps --filter "name=open-lola-ultragrid-rxtx" -q)
}

trap cleanup EXIT

capture_managed_rx_log() {
  local container_id=""

  container_id="$(docker ps --filter "name=open-lola-ultragrid-rxtx-rx" -q | head -n 1)"
  if [[ -n "$container_id" ]]; then
    docker logs "$container_id" >"$managed_rx_live_log" 2>&1 || true
  else
    : >"$managed_rx_live_log"
  fi
}

write_connection_metrics() {
  local tx_started_ms="$1"
  local connected_ms="$2"
  local elapsed_ms=""
  local connected=false

  if [[ "$connected_ms" -gt 0 ]]; then
    elapsed_ms="$((connected_ms - tx_started_ms))"
    connected=true
  fi

  python3 - "$connection_metrics" "$connected" "$elapsed_ms" "$connection_timeout_seconds" "$connection_poll_seconds" "$managed_rx_live_log" <<'PY'
import json
import sys

path, connected, elapsed_ms, timeout_seconds, poll_seconds, live_log = sys.argv[1:]
payload = {
    "schema": "open-lola-ultragrid-managed-connection-metrics-v1",
    "connected": connected == "true",
    "audioVideoConnectionMs": int(elapsed_ms) if elapsed_ms else None,
    "connectionTimeoutSeconds": int(timeout_seconds),
    "connectionPollSeconds": float(poll_seconds),
    "liveRxLog": live_log,
    "evidenceBoundary": (
        "Measured from Open LoLa-managed TX command start until the managed RX "
        "Docker log first contains incoming audio and video format lines."
    ),
}
with open(path, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY
}

wait_for_managed_connection() {
  local tx_started_ms="$1"
  local connected_ms=0
  local deadline_ms=$((tx_started_ms + connection_timeout_seconds * 1000))

  while [[ "$(parity_monotonic_ms)" -le "$deadline_ms" ]]; do
    capture_managed_rx_log
    if grep -Fq "New incoming audio format detected" "$managed_rx_live_log" \
      && grep -Fq "New incoming video format detected" "$managed_rx_live_log"; then
      connected_ms="$(parity_monotonic_ms)"
      break
    fi
    sleep "$connection_poll_seconds"
  done

  capture_managed_rx_log
  write_connection_metrics "$tx_started_ms" "$connected_ms"

  if [[ "$connected_ms" -eq 0 ]]; then
    echo "Open LoLa-managed UltraGrid RX did not receive audio and video within ${connection_timeout_seconds}s: $managed_rx_live_log" >&2
    exit 1
  fi
}

wait_for_managed_rx_ready() {
  local started_ms="$1"
  local deadline_ms=$((started_ms + rx_startup_timeout_seconds * 1000))
  local ready=false

  while [[ "$(parity_monotonic_ms)" -le "$deadline_ms" ]]; do
    capture_managed_rx_log
    if grep -Fq "Audio sending started." "$managed_rx_live_log" \
      && grep -Fq "Audio receiving started." "$managed_rx_live_log" \
      && grep -Fq "Control socket listening" "$managed_rx_live_log"; then
      ready=true
      break
    fi
    sleep "$connection_poll_seconds"
  done

  if [[ "$ready" != true ]]; then
    echo "Open LoLa-managed UltraGrid RX did not become ready within ${rx_startup_timeout_seconds}s: $managed_rx_live_log" >&2
    exit 1
  fi
}

rx_started_ms="$(parity_monotonic_ms)"
OPEN_LOLA_ULTRAGRID_DOCKER_NAME_PREFIX=open-lola-ultragrid-rxtx-rx \
  "$open_lola_bin" external-connector-session-run \
  --connector mvtp-ultragrid \
  --role rx \
  --peer host.docker.internal \
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
  --executable scripts/open-lola-ultragrid-docker-client.sh &
rx_pid=$!
if ! kill -0 "$rx_pid" >/dev/null 2>&1; then
  echo "Open LoLa-managed UltraGrid RX process failed to start." >&2
  exit 1
fi
sleep 0.5

wait_for_managed_rx_ready "$rx_started_ms"

tx_started_ms="$(parity_monotonic_ms)"
OPEN_LOLA_ULTRAGRID_DOCKER_NAME_PREFIX=open-lola-ultragrid-rxtx-tx \
  "$open_lola_bin" external-connector-session-run \
  --connector mvtp-ultragrid \
  --role tx \
  --peer host.docker.internal \
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
  --executable scripts/open-lola-ultragrid-docker-client.sh &
tx_pid=$!

wait_for_managed_connection "$tx_started_ms"
wait "$tx_pid"

wait "$rx_pid"

"$open_lola_bin" validate-external-connector-session-report "$rx_report"
"$open_lola_bin" validate-external-connector-session-report "$tx_report"

echo "UltraGrid RX report: $rx_report"
echo "UltraGrid TX report: $tx_report"
echo "UltraGrid connection metrics: $connection_metrics"
echo "VERDICT: PARTIAL"
