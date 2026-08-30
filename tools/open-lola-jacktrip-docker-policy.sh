#!/usr/bin/env bash
# Launch jacktrip-docker-policy through the Open LoLa compatibility path.
set -euo pipefail

# Return the exact pinned JackTrip image required by local parity scripts.
open_lola_required_jacktrip_docker_image() {
  local image="${OPEN_LOLA_JACKTRIP_DOCKER_IMAGE:-}"
  if [[ -z "$image" ]]; then
    echo "OPEN_LOLA_JACKTRIP_DOCKER_IMAGE must be set to a reviewed JackTrip image tag or digest." >&2
    echo "Refusing the former unsafe default jacktrip/jacktrip:latest." >&2
    return 64
  fi
  case "$image" in
    *:latest|latest|*":latest@"*)
      echo "OPEN_LOLA_JACKTRIP_DOCKER_IMAGE must not use the mutable latest tag: $image" >&2
      return 64
      ;;
  esac
  printf '%s\n' "$image"
}
