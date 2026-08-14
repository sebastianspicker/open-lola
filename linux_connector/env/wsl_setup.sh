#!/usr/bin/env bash
# Compatibility entry point for the canonical WSL setup script.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
exec "$script_dir/../deployment/wsl/wsl_setup.sh" "$@"
