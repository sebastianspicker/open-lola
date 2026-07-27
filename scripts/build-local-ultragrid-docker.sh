#!/usr/bin/env bash
# Build the pinned UltraGrid image used by local Open LoLa transport experiments.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/open-lola-ultragrid-docker-policy.sh
source "$script_dir/open-lola-ultragrid-docker-policy.sh"

image="$(open_lola_required_ultragrid_docker_image)"
dockerfile_dir="scripts/ultragrid-docker"

docker build -t "$image" "$dockerfile_dir" "$@"

echo "UltraGrid Docker image built: $image"
