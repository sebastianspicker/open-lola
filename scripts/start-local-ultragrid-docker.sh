#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/open-lola-ultragrid-docker-policy.sh
source "$script_dir/open-lola-ultragrid-docker-policy.sh"

container_name="${1:-open-lola-ultragrid-local}"
# Override with OPEN_LOLA_ULTRAGRID_DOCKER_IMAGE; the shared policy rejects mutable latest tags.
image="$(open_lola_required_ultragrid_docker_image)"
video_port="${OPEN_LOLA_ULTRAGRID_VIDEO_PORT:-5004}"
audio_port="${OPEN_LOLA_ULTRAGRID_AUDIO_PORT:-5006}"
video_capture="${OPEN_LOLA_ULTRAGRID_VIDEO_CAPTURE:-testcard:640:360:10:RGB}"

if docker ps --format '{{.Names}}' | grep -Fxq "$container_name"; then
  echo "UltraGrid container already running: $container_name"
  exit 0
fi

docker run \
  --rm \
  --name "$container_name" \
  -p "$video_port:$video_port/udp" \
  -p "$audio_port:$audio_port/udp" \
  -d "$image" \
  -t "$video_capture" \
  -P "$video_port:$video_port:$audio_port:$audio_port" \
  --server

echo "UltraGrid server container started: $container_name"
echo "Stop it with: docker stop $container_name"
