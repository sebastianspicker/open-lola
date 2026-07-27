#!/usr/bin/env bash
# Start the pinned JackTrip container used by local Open LoLa parity checks.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/open-lola-jacktrip-docker-policy.sh
source "$script_dir/open-lola-jacktrip-docker-policy.sh"

container_name="${1:-open-lola-jacktrip-local}"
image="$(open_lola_required_jacktrip_docker_image)"
audio_port="${OPEN_LOLA_JACKTRIP_AUDIO_PORT:-4464}"
udp_range="${OPEN_LOLA_JACKTRIP_UDP_RANGE:-61000-61100}"
sample_rate="${OPEN_LOLA_JACKTRIP_SAMPLE_RATE:-48000}"
buffer_size="${OPEN_LOLA_JACKTRIP_BUFFER_SIZE:-128}"
shm_size="${OPEN_LOLA_JACKTRIP_DOCKER_SHM_SIZE:-512M}"
memlock="${OPEN_LOLA_JACKTRIP_DOCKER_MEMLOCK:-512000000}"
rtprio="${OPEN_LOLA_JACKTRIP_DOCKER_RTPRIO:-10}"

if docker ps --format '{{.Names}}' | grep -Fxq "$container_name"; then
  echo "JackTrip container already running: $container_name"
  exit 0
fi

docker run \
  --rm \
  --name "$container_name" \
  --ulimit "memlock=$memlock:$memlock" \
  --ulimit "rtprio=$rtprio" \
  --shm-size="$shm_size" \
  -e "SAMPLE_RATE=$sample_rate" \
  -e "BUFFER_SIZE=$buffer_size" \
  -e "JACKTRIP_OPTS=-s" \
  -p "$audio_port:$audio_port/tcp" \
  -p "$audio_port:$audio_port/udp" \
  -p "$udp_range:$udp_range/udp" \
  -d "$image"

echo "JackTrip P2P server container started: $container_name"
echo "Stop it with: docker stop $container_name"
