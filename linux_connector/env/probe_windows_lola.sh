#!/usr/bin/env bash
set -euo pipefail

WINDOWS_IP=""
LOCAL_IP=""
DURATION="20"
WIDTH="640"
HEIGHT="480"
FPS="25"
BPP="8"
CHANNELS="2"
SR="44100"
CAPTURE=""
TEST_MEDIA="diagnostic"

usage() {
  cat <<'EOF'
Usage:
  probe_windows_lola.sh --windows-ip <ip> [options]

Options:
  --local-ip <ip>        Linux/WSL source IP. Auto-detected from route if omitted.
  --duration <seconds>   Diagnostic AV duration. Default: 20.
  --width <pixels>       Video width. Default: 640.
  --height <pixels>      Video height. Default: 480.
  --fps <fps>            Video FPS. Default: 25.
  --bpp <bits>           Video bits per pixel. Default: 8.
  --channels <n>         Audio channel count. Default: 2.
  --sr <hz>              Audio sample rate. Default: 44100.
  --test-media <mode>    silence, sine, tones, diagnostic. Default: diagnostic.
  --capture <pcap>       Also run tcpdump capture to this pcap file.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --windows-ip) WINDOWS_IP="$2"; shift 2 ;;
    --local-ip) LOCAL_IP="$2"; shift 2 ;;
    --duration) DURATION="$2"; shift 2 ;;
    --width) WIDTH="$2"; shift 2 ;;
    --height) HEIGHT="$2"; shift 2 ;;
    --fps) FPS="$2"; shift 2 ;;
    --bpp) BPP="$2"; shift 2 ;;
    --channels) CHANNELS="$2"; shift 2 ;;
    --sr) SR="$2"; shift 2 ;;
    --test-media) TEST_MEDIA="$2"; shift 2 ;;
    --capture) CAPTURE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -z "$WINDOWS_IP" ]]; then
  echo "--windows-ip is required" >&2
  usage >&2
  exit 1
fi

if [[ -z "$LOCAL_IP" ]]; then
  LOCAL_IP="$(ip route get "$WINDOWS_IP" | awk '{for (i=1; i<=NF; i++) if ($i=="src") {print $(i+1); exit}}')"
fi

if [[ -z "$LOCAL_IP" ]]; then
  echo "Could not auto-detect local source IP. Pass --local-ip explicitly." >&2
  exit 1
fi

echo "Linux-LoLa probe"
echo "  local-ip:   $LOCAL_IP"
echo "  windows-ip: $WINDOWS_IP"
echo "  media:      $TEST_MEDIA ${WIDTH}x${HEIGHT}@${FPS} bpp=${BPP}, audio ${CHANNELS}ch/${SR}Hz"

echo
echo "[1/3] Local bidirectional UDP selftest"
python -m linux_connector.lola_connector.cli --local-ip 127.0.0.1 selftest --duration 0.15

echo
echo "[2/3] Windows LoLa status probe"
python -m linux_connector.lola_connector.cli --local-ip "$LOCAL_IP" status "$WINDOWS_IP"

if [[ -n "$CAPTURE" ]]; then
  echo
  echo "Starting tcpdump capture: $CAPTURE"
  sudo tcpdump -i any -w "$CAPTURE" "udp port 7000 or udp port 19788 or udp port 19798" &
  TCPDUMP_PID=$!
  trap 'sudo kill "$TCPDUMP_PID" >/dev/null 2>&1 || true' EXIT
  sleep 1
fi

echo
echo "[3/3] Diagnostic AV QuickConn"
python -m linux_connector.lola_connector.cli \
  --local-ip "$LOCAL_IP" \
  --sr "$SR" --bps 16 --channels "$CHANNELS" \
  --fps "$FPS" --bpp "$BPP" --width "$WIDTH" --height "$HEIGHT" --compression 0 \
  connect "$WINDOWS_IP" --rx --test-media "$TEST_MEDIA" --duration "$DURATION"

if [[ -n "${TCPDUMP_PID:-}" ]]; then
  sudo kill "$TCPDUMP_PID" >/dev/null 2>&1 || true
  wait "$TCPDUMP_PID" 2>/dev/null || true
  trap - EXIT
  echo "Capture written: $CAPTURE"
fi
