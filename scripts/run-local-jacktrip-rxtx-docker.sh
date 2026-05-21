#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/parity.sh
# shellcheck disable=SC1091
source "$script_dir/lib/parity.sh"

open_lola_bin="${OPEN_LOLA_BIN:-.build/debug/open-lola}"
output_dir="$(parity_output_dir "jacktrip-rxtx" "${1:-}")"
rx_duration_seconds="${OPEN_LOLA_CONNECTOR_DURATION_SECONDS:-18}"
tx_duration_seconds="${OPEN_LOLA_JACKTRIP_TX_DURATION_SECONDS:-8}"
startup_seconds="${OPEN_LOLA_JACKTRIP_STARTUP_SECONDS:-4}"
audio_port="${OPEN_LOLA_JACKTRIP_AUDIO_PORT:-4464}"
rx_report="$output_dir/jacktrip-rx.json"
tx_report="$output_dir/jacktrip-tx.json"
rx_journal="$output_dir/jacktrip-rx-journal.log"
rx_docker_log="$output_dir/jacktrip-rx-docker.log"

minimum_rx_duration=$((startup_seconds + tx_duration_seconds + 2))
if ((rx_duration_seconds < minimum_rx_duration)); then
  rx_duration_seconds="$minimum_rx_duration"
fi

mkdir -p "$output_dir"

parity_require_docker_daemon "Open LoLa-managed JackTrip Docker RX/TX"

cleanup() {
  parity_stop_docker_containers_by_name_prefix "open-lola-jacktrip-rxtx"
}

trap cleanup EXIT

OPEN_LOLA_JACKTRIP_DOCKER_NAME_PREFIX=open-lola-jacktrip-rxtx-rx \
  "$open_lola_bin" external-connector-session-run \
  --connector jacktrip \
  --role rx \
  --output "$rx_report" \
  --dry-run false \
  --media audio \
  --duration-seconds "$rx_duration_seconds" \
  --audio-port "$audio_port" \
  --channels 2 \
  --sample-rate 48000 \
  --frames 128 \
  --executable scripts/open-lola-jacktrip-docker-client.sh &
rx_pid=$!

sleep "$startup_seconds"

OPEN_LOLA_JACKTRIP_DOCKER_NAME_PREFIX=open-lola-jacktrip-rxtx-tx \
  "$open_lola_bin" external-connector-session-run \
  --connector jacktrip \
  --role tx \
  --peer host.docker.internal \
  --output "$tx_report" \
  --dry-run false \
  --media audio \
  --duration-seconds "$tx_duration_seconds" \
  --audio-port "$audio_port" \
  --channels 2 \
  --sample-rate 48000 \
  --frames 128 \
  --executable scripts/open-lola-jacktrip-docker-client.sh

rx_container="$(docker ps --filter "name=open-lola-jacktrip-rxtx-rx" -q | head -n 1)"
if [[ -n "$rx_container" ]]; then
  docker logs "$rx_container" >"$rx_docker_log" 2>&1 || true
  docker exec "$rx_container" journalctl -u jacktrip --no-pager -n 200 >"$rx_journal" || true
fi

wait "$rx_pid"

"$open_lola_bin" validate-external-connector-session-report "$rx_report"
"$open_lola_bin" validate-external-connector-session-report "$tx_report"

if [[ ! -s "$rx_journal" ]]; then
  echo "JackTrip RX journal was not captured: $rx_journal" >&2
  exit 1
fi

if ! grep -Fq "Received Connection from Peer!" "$rx_journal"; then
  echo "JackTrip RX journal did not record a peer connection: $rx_journal" >&2
  exit 1
fi

echo "JackTrip RX report: $rx_report"
echo "JackTrip TX report: $tx_report"
echo "JackTrip RX journal: $rx_journal"
echo "JackTrip RX docker log: $rx_docker_log"
echo "VERDICT: PARTIAL"
