#!/usr/bin/env bash
# Install the Linux packages and virtual environment needed for WSL LoLa self-tests.
set -euo pipefail

if ! command -v apt-get >/dev/null 2>&1; then
  echo "This setup script expects an apt-based WSL distro such as Ubuntu." >&2
  exit 1
fi

sudo apt-get update
sudo apt-get install -y \
  python3 \
  python3-venv \
  python3-pip \
  ffmpeg \
  iproute2 \
  iputils-ping \
  netcat-openbsd \
  tcpdump

python3 -m venv .venv
# shellcheck source=/dev/null
source .venv/bin/activate
python -m pip install --upgrade pip

python -m linux_connector.lola_connector.cli --local-ip 127.0.0.1 selftest --duration 0.15

cat <<'MSG'

WSL Linux-LoLa test environment is ready.

Next:
  ./linux_connector/deployment/wsl/probe_windows_lola.sh --windows-ip <windows-lola-ip> --local-ip <wsl-ip>

To discover candidate IPs:
  ip -4 addr
  ip route
MSG
