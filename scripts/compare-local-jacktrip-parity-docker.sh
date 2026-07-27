#!/usr/bin/env bash
# Compare managed and direct JackTrip Docker runs with retained local evidence.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/parity.sh
# shellcheck disable=SC1091
source "$script_dir/lib/parity.sh"
# shellcheck source=scripts/open-lola-jacktrip-docker-policy.sh
source "$script_dir/open-lola-jacktrip-docker-policy.sh"

open_lola_bin="${OPEN_LOLA_BIN:-$(open_lola_default_cli_binary)}"
output_dir="$(parity_output_dir "jacktrip-parity" "${1:-}")"
image="$(open_lola_required_jacktrip_docker_image)"
audio_port="${OPEN_LOLA_JACKTRIP_AUDIO_PORT:-4464}"
sample_rate="${OPEN_LOLA_JACKTRIP_SAMPLE_RATE:-48000}"
buffer_size="${OPEN_LOLA_JACKTRIP_BUFFER_SIZE:-128}"
startup_seconds="${OPEN_LOLA_JACKTRIP_STARTUP_SECONDS:-4}"
tx_duration_seconds="${OPEN_LOLA_JACKTRIP_TX_DURATION_SECONDS:-8}"
connection_timeout_seconds="${OPEN_LOLA_JACKTRIP_CONNECTION_TIMEOUT_SECONDS:-$tx_duration_seconds}"
max_managed_delta_seconds="${OPEN_LOLA_JACKTRIP_MAX_MANAGED_CONNECTION_DELTA_SECONDS:-2}"
shm_size="${OPEN_LOLA_JACKTRIP_DOCKER_SHM_SIZE:-512M}"
memlock="${OPEN_LOLA_JACKTRIP_DOCKER_MEMLOCK:-512000000}"
rtprio="${OPEN_LOLA_JACKTRIP_DOCKER_RTPRIO:-10}"

prefix="open-lola-jacktrip-parity-$$"
network_name="$prefix-net"
direct_rx_name="$prefix-direct-rx"
direct_tx_name="$prefix-direct-tx"
direct_dir="$output_dir/direct-jacktrip"
managed_dir="$output_dir/open-lola-managed"
direct_rx_journal="$direct_dir/jacktrip-rx-journal.log"
direct_tx_journal="$direct_dir/jacktrip-tx-journal.log"
direct_rx_docker_log="$direct_dir/jacktrip-rx-docker.log"
direct_tx_docker_log="$direct_dir/jacktrip-tx-docker.log"
managed_rx_journal="$managed_dir/jacktrip-rx-journal.log"
managed_rx_report="$managed_dir/jacktrip-rx.json"
managed_tx_report="$managed_dir/jacktrip-tx.json"

mkdir -p "$direct_dir" "$managed_dir"

parity_require_docker_daemon "JackTrip Docker parity"

# Stop both JackTrip containers before removing temporary parity evidence.
cleanup() {
  docker stop "$direct_tx_name" "$direct_rx_name" >/dev/null 2>&1 || true
  docker network rm "$network_name" >/dev/null 2>&1 || true
}

trap cleanup EXIT

# Start the direct JackTrip baseline container with its journal captured separately.
run_direct_container() {
  local name="$1"
  local jacktrip_opts="$2"
  local publish_audio="${3:-false}"
  local docker_args=(
    run
    --rm
    --detach
    --name "$name"
    --network "$network_name"
    --add-host host.docker.internal:host-gateway
    --ulimit "memlock=$memlock:$memlock"
    --ulimit "rtprio=$rtprio"
    --shm-size="$shm_size"
    -e "SAMPLE_RATE=$sample_rate"
    -e "BUFFER_SIZE=$buffer_size"
    -e "JACKTRIP_OPTS=$jacktrip_opts"
  )

  if [[ "$publish_audio" == true ]]; then
    docker_args+=(
      -p "$audio_port:$audio_port/tcp"
      -p "$audio_port:$audio_port/udp"
    )
  fi

  docker_args+=("$image")
  docker "${docker_args[@]}" >/dev/null
}

# Copy a container's systemd journal into the parity evidence directory.
capture_journal() {
  local container_name="$1"
  local journal_path="$2"
  local docker_log_path="$3"

  docker logs "$container_name" >"$docker_log_path" 2>&1 || true
  docker exec "$container_name" journalctl -u jacktrip --no-pager -n 200 >"$journal_path" || true
}

# Require the journal marker that proves JackTrip established a peer connection.
require_peer_connection() {
  local label="$1"
  local journal_path="$2"

  if [[ ! -s "$journal_path" ]]; then
    echo "$label journal was not captured: $journal_path" >&2
    exit 1
  fi

  if ! grep -Fq "Received Connection from Peer!" "$journal_path"; then
    echo "$label journal did not record a peer connection: $journal_path" >&2
    exit 1
  fi
}

docker network create "$network_name" >/dev/null

run_direct_container \
  "$direct_rx_name" \
  "-s -n 2 -q 4 -r 1 -B $audio_port" \
  true

sleep "$startup_seconds"

run_direct_container \
  "$direct_tx_name" \
  "-c host.docker.internal -n 2 -q 4 -r 1 -B $((audio_port + 1)) -P $audio_port"

direct_connected=false
for ((second = 0; second < connection_timeout_seconds; second++)); do
  capture_journal "$direct_rx_name" "$direct_rx_journal" "$direct_rx_docker_log"
  if grep -Fq "Received Connection from Peer!" "$direct_rx_journal"; then
    direct_connected=true
    break
  fi
  sleep 1
done

if [[ "$direct_connected" != true ]]; then
  echo "Direct JackTrip RX did not connect within ${connection_timeout_seconds}s: $direct_rx_journal" >&2
  exit 1
fi

capture_journal "$direct_rx_name" "$direct_rx_journal" "$direct_rx_docker_log"
capture_journal "$direct_tx_name" "$direct_tx_journal" "$direct_tx_docker_log"
require_peer_connection "Direct JackTrip RX" "$direct_rx_journal"
parity_require_text "Direct JackTrip RX journal" "$direct_rx_journal" "The Sampling Rate is: $sample_rate"
parity_require_text "Direct JackTrip RX journal" "$direct_rx_journal" "The Audio Buffer Size is: $buffer_size samples"
docker stop "$direct_tx_name" "$direct_rx_name" >/dev/null 2>&1 || true

OPEN_LOLA_BIN="$open_lola_bin" \
OPEN_LOLA_CONNECTOR_DURATION_SECONDS="$((startup_seconds + tx_duration_seconds + 2))" \
OPEN_LOLA_JACKTRIP_TX_DURATION_SECONDS="$tx_duration_seconds" \
OPEN_LOLA_JACKTRIP_STARTUP_SECONDS="$startup_seconds" \
OPEN_LOLA_JACKTRIP_AUDIO_PORT="$audio_port" \
OPEN_LOLA_JACKTRIP_SAMPLE_RATE="$sample_rate" \
OPEN_LOLA_JACKTRIP_BUFFER_SIZE="$buffer_size" \
OPEN_LOLA_JACKTRIP_DOCKER_IMAGE="$image" \
  bash scripts/run-local-jacktrip-rxtx-docker.sh "$managed_dir"

require_peer_connection "Open LoLa-managed JackTrip RX" "$managed_rx_journal"
parity_require_text "Open LoLa-managed JackTrip RX journal" "$managed_rx_journal" "The Sampling Rate is: $sample_rate"
parity_require_text "Open LoLa-managed JackTrip RX journal" "$managed_rx_journal" "The Audio Buffer Size is: $buffer_size samples"
parity_require_jacktrip_connection_delay_near_direct "$direct_rx_journal" "$managed_rx_journal" "$max_managed_delta_seconds"
parity_require_text "Open LoLa-managed JackTrip RX report" "$managed_rx_report" '"-q"'
parity_require_text "Open LoLa-managed JackTrip RX report" "$managed_rx_report" '"4"'
parity_require_text "Open LoLa-managed JackTrip RX report" "$managed_rx_report" '"-r"'
parity_require_text "Open LoLa-managed JackTrip RX report" "$managed_rx_report" '"1"'
parity_require_text "Open LoLa-managed JackTrip RX report" "$managed_rx_report" '"-B"'
parity_require_text "Open LoLa-managed JackTrip RX report" "$managed_rx_report" "\"$audio_port\""
parity_require_text "Open LoLa-managed JackTrip TX report" "$managed_tx_report" '"-P"'
parity_require_text "Open LoLa-managed JackTrip TX report" "$managed_tx_report" "\"$audio_port\""

echo "Direct JackTrip RX journal: $direct_rx_journal"
echo "Direct JackTrip TX journal: $direct_tx_journal"
echo "Open LoLa-managed JackTrip RX journal: $managed_rx_journal"
echo "Open LoLa-managed JackTrip RX report: $managed_rx_report"
echo "Open LoLa-managed JackTrip TX report: $managed_tx_report"
echo "connection-timeout-seconds: $connection_timeout_seconds"
echo "VERDICT: PARTIAL"
