#!/usr/bin/env bash
# Run a same-host macOS connector to Rust station LoLa session and record both reports.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
# shellcheck source=tools/lib/parity.sh
# shellcheck disable=SC1091
source "$script_dir/lib/parity.sh"

# Return a second local IPv4 address for the Rust station: 127.0.0.2 on Linux,
# otherwise the address of the default route (macOS only has 127.0.0.1 on lo0).
default_rust_ip() {
  if [[ "$(uname -s)" == Linux ]]; then
    printf '127.0.0.2\n'
    return
  fi
  python3 -c '
import socket
probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
try:
    probe.connect(("192.0.2.1", 9))
    address = probe.getsockname()[0]
except OSError:
    address = ""
print("" if address.startswith("127.") or address == "0.0.0.0" else address)
'
}

# Return the Rust station binary, building the headless release binary when unset
# (debug builds run the media loop too slowly for representative throughput).
rusty_lola_binary() {
  if [[ -n "${OPEN_LOLA_RUSTY_LOLA_BIN:-}" ]]; then
    printf '%s\n' "$OPEN_LOLA_RUSTY_LOLA_BIN"
    return
  fi
  (cd "$repo_root" && cargo build --quiet --release -p rusty-lola --no-default-features) >&2
  printf '%s\n' "${CARGO_TARGET_DIR:-$repo_root/target}/release/rusty-lola"
}

open_lola_bin="${OPEN_LOLA_BIN:-$(open_lola_default_cli_binary)}"
rusty_lola_bin="$(rusty_lola_binary)"
output_dir="$(parity_output_dir "lola-interop" "${1:-}")"
mac_ip="${OPEN_LOLA_LOLA_MAC_IP:-127.0.0.1}"
rust_ip="${OPEN_LOLA_LOLA_RUST_IP:-$(default_rust_ip)}"
media="${OPEN_LOLA_LOLA_MEDIA:-audio-video}"
duration_seconds="${OPEN_LOLA_CONNECTOR_DURATION_SECONDS:-5}"
rust_report="$output_dir/rust-listen.json"
rust_log="$output_dir/rust-listen.log"
mac_report="$output_dir/mac-connector.json"
mac_log="$output_dir/mac-connector.log"
rust_pid=""

[[ -n "$rust_ip" ]] || fail "no second local IPv4 address; set OPEN_LOLA_LOLA_RUST_IP"
[[ "$rust_ip" != "$mac_ip" ]] || fail "the Rust and macOS addresses must differ: $rust_ip"
mkdir -p "$output_dir"

# Stop the Rust listener if the script exits before it finishes.
cleanup() {
  if [[ -n "$rust_pid" ]]; then
    kill "$rust_pid" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

# Each side binds its own address on the standard LoLa ports, so the control
# source-port pins hold exactly as on a LAN. The diagnostic camera is not a
# Bayer sensor, so --bayer 0 keeps the shared Mono8 default tuple. The listener
# starts first with the same duration, so it ends the session with DISCONNECT;
# either side then reports a clean end ("peer disconnected").
rust_media_args=(--bayer 0)
if [[ "$media" == audio ]]; then
  rust_media_args=(--audio-only)
fi
"$rusty_lola_bin" listen \
  --remote-ip "$mac_ip" --local-ip "$rust_ip" --bind-ip "$rust_ip" \
  --audio-backend diagnostic --camera-backend diagnostic "${rust_media_args[@]}" \
  --timeout 10 --continuous --duration "$duration_seconds" \
  --report "$rust_report" >"$rust_log" 2>&1 &
rust_pid=$!
sleep 1
kill -0 "$rust_pid" >/dev/null 2>&1 || fail "Rust listener exited early: $rust_log"

mac_status=0
"$open_lola_bin" external-connector-session-run \
  --connector lola --role tx-rx \
  --peer "$rust_ip" --local-host "$mac_ip" \
  --media "$media" \
  --duration-seconds "$duration_seconds" --dry-run false \
  --output "$mac_report" >"$mac_log" 2>&1 || mac_status=$?

rust_status=0
wait "$rust_pid" || rust_status=$?
rust_pid=""

python3 - "$rust_report" <<'PY' || true
import json
import sys

try:
    with open(sys.argv[1], encoding="utf-8") as handle:
        report = json.load(handle)
except (OSError, ValueError) as error:
    print(f"Rust report unreadable: {error}")
    sys.exit(0)
for key in ("ok", "error", "messages_received", "messages_sent", "rejected", "reject_text",
            "audio_frames_received", "audio_frames_sent", "video_frames_received",
            "video_frames_sent"):
    print(f"rust.{key}: {report.get(key)}")
PY

echo "Rust listener log: $rust_log (exit $rust_status)"
echo "Rust listener report: $rust_report"
echo "macOS connector log: $mac_log (exit $mac_status)"
echo "macOS connector report: $mac_report"
if [[ "$mac_status" -ne 0 || "$rust_status" -ne 0 ]]; then
  echo "VERDICT: FAIL"
  exit 1
fi
"$open_lola_bin" validate-external-connector-session-report "$mac_report"
echo "VERDICT: PARTIAL"
