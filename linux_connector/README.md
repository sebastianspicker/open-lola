# LoLa Linux Connector Prototype

Date: 2026-07-24
Status: experimental compatibility source; publication review pending
Verdict: PARTIAL

This package is a Linux-side compatibility prototype for observed LoLa 2.0.0
XIMEA behavior. It models the control, audio, and video behavior needed for a
Windows peer to connect to a Linux peer and exchange synthetic media.

Current source covers constrained control and synthetic bidirectional
audio/video paths. This is not a drop-in compatibility, supported backend,
low-latency, or current field-validation claim. Native
Linux capture/playout, target-hardware latency, inbound-media parity, fixture
provenance, and clean-room/publication review remain open.

## Quick Commands

Run from `<LOLA_PACKAGE_DIR>`, the directory that contains `linux_connector/`.
Use the repository's Python 3.14.6 pin and install `uv`, then create the locked
environment once with `uv sync --locked --extra dev`. Python 3.11 remains the
supported lower bound. Ordinary UDP commands do not require elevated privileges;
packet-capture and raw-socket helpers may require platform-specific capabilities
and should be granted only for the individual validation command.

```bash
uv run --locked python -m linux_connector.lola_connector.cli --local-ip 127.0.0.1 selftest --duration 0.25
```

Probe a Windows LoLa peer:

```bash
uv run --locked python -m linux_connector.lola_connector.cli --local-ip <LINUX_LOLA_IP> status <WINDOWS_LOLA_IP>
```

Listen for Windows LoLa and transmit synthetic diagnostic audio/video:

```bash
uv run --locked python -m linux_connector.lola_connector.cli \
  --local-ip <LINUX_LOLA_IP> \
  --sr 44100 --bps 16 --channels 2 \
  --fps 25 --bpp 8 --width 640 --height 480 --compression 0 \
  --audio-interval-scale 0.92 \
  listen --rx --test-media diagnostic --duration 20
```

## Validation

Capture current validation evidence outside the repository and use the
acceptance gates in [Windows Validation](docs/windows-validation.md). Do not
treat dated lab observations as proof of the current revision.

## Documentation

The canonical documentation lives in [docs/index.md](docs/index.md).

Start with:

- [Quickstart](docs/quickstart.md) for self-test, status probe, listen/connect, and synthetic media.
- [WSL Lab Setup](docs/wsl-lab-setup.md) for same-machine Windows/WSL validation.
- [Windows Validation](docs/windows-validation.md) for acceptance gates.
- [Troubleshooting](docs/troubleshooting.md) for symptom-led debugging.
- [Protocol Reference](docs/protocol-reference.md) for ports, control messages, audio, video, and transport behavior.
- [Roadmap](docs/roadmap.md) for native Linux backend work.

## Repository Layout

- `lola_connector/`: connector package and runtime.
- `deployment/wsl/`: WSL, Docker, and Windows lab deployment helpers.
- `tools/`: packet capture and diagnostic helpers.
- `tests/`: protocol and codec tests.
- `docs/`: canonical public documentation.
- `process_artifacts/`: ignored local-only reverse-engineering and lab artifacts.

## Public Boundary

Public docs summarize externally observable behavior, implementation
hypotheses, validation procedures, and connector source written for this
project. Detailed protocol material remains subject to the repository's
clean-room/publication review before any public release. Raw process output,
decompiler text, captures, binary artifacts, and environment-specific lab
material must never be committed.

VERDICT: PARTIAL
