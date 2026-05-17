#!/usr/bin/env bash
set -euo pipefail

executable="${OPEN_LOLA_ULTRAGRID_NATIVE_EXECUTABLE:-uv}"
mode="${OPEN_LOLA_ULTRAGRID_NATIVE_MODE:-${OPEN_LOLA_EXTERNAL_CONNECTOR_ROLE:-client}}"
log_path="${OPEN_LOLA_ULTRAGRID_NATIVE_LOG:-}"

case "${1:-}" in
  -h|--help|-v|--version)
    exec "$executable" "$@"
    ;;
esac

identity_text="$("$executable" -h 2>&1 || true)"
identity_lower="$(printf '%s' "$identity_text" | tr '[:upper:]' '[:lower:]')"
if [[ "$identity_lower" == *"python package manager"* ]]; then
  echo "Refusing to launch Python uv as UltraGrid: $executable" >&2
  exit 69
fi

if [[ -n "$log_path" ]]; then
  mkdir -p "$(dirname "$log_path")"
  exec > >(tee -a "$log_path") 2>&1
fi

ultragrid_args=()
peer=""
peer_index=-1
port_map="${OPEN_LOLA_ULTRAGRID_PORT_MAP:-5004:5004:5006:5006}"

while (($#)); do
  case "$1" in
    -P)
      ultragrid_args+=("$1")
      shift
      if (($#)); then
        port_map="$1"
        ultragrid_args+=("$1")
        shift
      fi
      ;;
    *)
      ultragrid_args+=("$1")
      if [[ "$1" != -* ]]; then
        peer="$1"
        peer_index=$((${#ultragrid_args[@]} - 1))
      fi
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
    echo "Unsupported UltraGrid native mode: $mode" >&2
    exit 64
    ;;
esac

if [[ "$mode" == "server" ]]; then
  if ((peer_index >= 0)); then
    next_peer_index=$((peer_index + 1))
    ultragrid_args=("${ultragrid_args[@]:0:peer_index}" "${ultragrid_args[@]:$next_peer_index}")
  fi
  ultragrid_args+=(--server)
elif [[ "$mode" == "client" ]]; then
  if [[ -z "$peer" ]]; then
    echo "UltraGrid native client mode requires a peer host argument" >&2
    exit 64
  fi
  next_peer_index=$((peer_index + 1))
  ultragrid_args=("${ultragrid_args[@]:0:peer_index}" "${ultragrid_args[@]:$next_peer_index}")
  ultragrid_args+=(--client "$peer")
fi

export OPEN_LOLA_ULTRAGRID_PORT_MAP="$port_map"
exec "$executable" "${ultragrid_args[@]}"
