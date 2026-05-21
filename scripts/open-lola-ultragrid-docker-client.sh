#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/parity.sh
# shellcheck disable=SC1091
source "$script_dir/lib/parity.sh"
# shellcheck source=scripts/open-lola-ultragrid-docker-policy.sh
source "$script_dir/open-lola-ultragrid-docker-policy.sh"

# Override with OPEN_LOLA_ULTRAGRID_DOCKER_IMAGE; the shared policy rejects mutable latest tags.
image="$(open_lola_required_ultragrid_docker_image)"
parity_require_docker_daemon "UltraGrid Docker client"
name_prefix="${OPEN_LOLA_ULTRAGRID_DOCKER_NAME_PREFIX:-open-lola-ultragrid-client}"
container_name="${name_prefix}-$$"
add_host="${OPEN_LOLA_ULTRAGRID_DOCKER_ADD_HOST:-host.docker.internal:host-gateway}"
mode="${OPEN_LOLA_ULTRAGRID_DOCKER_MODE:-${OPEN_LOLA_EXTERNAL_CONNECTOR_ROLE:-client}}"

case "${1:-}" in
  -h|--help|-v|--version)
    docker run --rm "$image" "$@"
    exit 0
    ;;
esac

ultragrid_args=()
peer=""
port_map="${OPEN_LOLA_ULTRAGRID_PORT_MAP:-5004:5004:5006:5006}"
while (($#)); do
  case "$1" in
    -P)
      ultragrid_args+=("$1")
      shift
      if (($#)); then
        port_map="$1"
        ultragrid_args+=("$1")
        peer="$1"
        shift
      fi
      ;;
    *)
      ultragrid_args+=("$1")
      peer="$1"
      shift
      ;;
  esac
done

case "$mode" in
  rx|server)
    mode="server"
    ;;
  tx|tx-rx|client)
    mode="client"
    ;;
  *)
    echo "Unsupported UltraGrid Docker mode: $mode" >&2
    exit 64
    ;;
esac

if [[ "$mode" == "server" && -n "$peer" && "$peer" != -* ]]; then
  ultragrid_args=("${ultragrid_args[@]:0:${#ultragrid_args[@]}-1}")
  ultragrid_args+=(--server)
elif [[ "$mode" == "client" && -n "$peer" && "$peer" != -* ]]; then
  ultragrid_args=("${ultragrid_args[@]:0:${#ultragrid_args[@]}-1}")
  ultragrid_args+=(--client "$peer")
fi

IFS=: read -r video_host_port video_container_port audio_host_port audio_container_port <<<"$port_map"
video_host_port="${video_host_port:-5004}"
video_container_port="${video_container_port:-$video_host_port}"
audio_host_port="${audio_host_port:-5006}"
audio_container_port="${audio_container_port:-$audio_host_port}"

docker_args=(
  run
  --rm
  --name
  "$container_name"
)

if [[ "$mode" == "server" ]]; then
  docker_args+=(
    -p "$video_host_port:$video_container_port/udp"
    -p "$audio_host_port:$audio_container_port/udp"
  )
fi

if [[ -n "$add_host" ]]; then
  docker_args+=(--add-host "$add_host")
fi

docker_args+=("$image")
docker_args+=("${ultragrid_args[@]}")

parity_run_docker_foreground "$container_name" "${docker_args[@]}"
