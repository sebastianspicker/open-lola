#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/open-lola-jacktrip-docker-policy.sh
source "$script_dir/open-lola-jacktrip-docker-policy.sh"

image="$(open_lola_required_jacktrip_docker_image)"
name_prefix="${OPEN_LOLA_JACKTRIP_DOCKER_NAME_PREFIX:-open-lola-jacktrip-client}"
container_name="${name_prefix}-$$"
shm_size="${OPEN_LOLA_JACKTRIP_DOCKER_SHM_SIZE:-512M}"
memlock="${OPEN_LOLA_JACKTRIP_DOCKER_MEMLOCK:-512000000}"
rtprio="${OPEN_LOLA_JACKTRIP_DOCKER_RTPRIO:-10}"
add_host="${OPEN_LOLA_JACKTRIP_DOCKER_ADD_HOST:-host.docker.internal:host-gateway}"
sample_rate="${OPEN_LOLA_JACKTRIP_SAMPLE_RATE:-48000}"
buffer_size="${OPEN_LOLA_JACKTRIP_BUFFER_SIZE:-128}"

case "${1:-}" in
  -h|--help|-v|--version)
    docker run --rm "$image" jacktrip "$@"
    exit 0
    ;;
esac

jacktrip_args=()
while (($#)); do
  case "$1" in
    -R)
      shift
      ;;
    --audioinputdevice|--audiooutputdevice)
      shift
      if (($#)); then
        shift
      fi
      ;;
    -T|--srate)
      shift
      if (($#)); then
        sample_rate="$1"
        shift
      fi
      ;;
    -F|--bufsize)
      shift
      if (($#)); then
        buffer_size="$1"
        shift
      fi
      ;;
    *)
      jacktrip_args+=("$1")
      shift
      ;;
  esac
done

is_server=false
audio_port="${OPEN_LOLA_JACKTRIP_AUDIO_PORT:-4464}"
for ((index = 0; index < ${#jacktrip_args[@]}; index++)); do
  case "${jacktrip_args[$index]}" in
    -s)
      is_server=true
      ;;
    -B|-P)
      next_index=$((index + 1))
      if ((next_index >= ${#jacktrip_args[@]})); then
        echo "jacktrip flag ${jacktrip_args[$index]} requires a port argument" >&2
        exit 1
      fi
      audio_port="${jacktrip_args[$next_index]}"
      ;;
  esac
done

jacktrip_args_env="$(printf '%s\n' "${jacktrip_args[@]}")"
# shellcheck disable=SC2016 # Expands inside the container shell, not in this host script.
container_command='jacktrip_args=(); if [[ -n "${OPEN_LOLA_JACKTRIP_ARGS:-}" ]]; then mapfile -t jacktrip_args <<< "$OPEN_LOLA_JACKTRIP_ARGS"; fi; exec jacktrip "${jacktrip_args[@]}"'

cleanup() {
  docker stop "$container_name" >/dev/null 2>&1 || true
}

terminate() {
  cleanup
  exit 143
}

trap cleanup EXIT
trap terminate INT TERM

docker_args=(
  run
  --rm
  --name "$container_name"
  --ulimit "memlock=$memlock:$memlock"
  --ulimit "rtprio=$rtprio"
  --shm-size="$shm_size"
  -e "OPEN_LOLA_JACKTRIP_ARGS=$jacktrip_args_env"
  -e "SAMPLE_RATE=$sample_rate"
  -e "BUFFER_SIZE=$buffer_size"
)

if [[ "$is_server" == true ]]; then
  docker_args+=(
    -p "$audio_port:$audio_port/tcp"
    -p "$audio_port:$audio_port/udp"
  )
fi

if [[ -n "$add_host" ]]; then
  docker_args+=(--add-host "$add_host")
fi

docker_args+=("$image" bash -lc "$container_command")

docker "${docker_args[@]}" &
docker_pid=$!
wait "$docker_pid"
