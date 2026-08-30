#!/usr/bin/env bash
# Launch ultragrid-docker-policy through the Open LoLa compatibility path.
set -euo pipefail

# Return the exact pinned UltraGrid image required by local parity scripts.
open_lola_required_ultragrid_docker_image() {
  local image="${OPEN_LOLA_ULTRAGRID_DOCKER_IMAGE:-open-lola-ultragrid:1.10.4}"
  case "$image" in
    *:latest|latest|*":latest@"*)
      echo "OPEN_LOLA_ULTRAGRID_DOCKER_IMAGE must not use the mutable latest tag: $image" >&2
      return 64
      ;;
  esac
  printf '%s\n' "$image"
}
