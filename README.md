# open-lola

[![Codacy Badge](https://app.codacy.com/project/badge/Grade/e3e98bcb5b1b4077910a11b11eaf89f6)](https://app.codacy.com/gh/sebastianspicker/open-lola/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)
[![tests](https://github.com/sebastianspicker/open-lola/actions/workflows/tests.yml/badge.svg)](https://github.com/sebastianspicker/open-lola/actions/workflows/tests.yml)
[![codeql](https://github.com/sebastianspicker/open-lola/actions/workflows/codeql.yml/badge.svg)](https://github.com/sebastianspicker/open-lola/actions/workflows/codeql.yml)
![python](https://img.shields.io/badge/python-3.11%2B-blue)
[![license](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

Open LoLa is an independent, educational interoperability project for making LoLa-style low-latency audio/video collaboration more accessible beyond Windows-only installations.

The first working component is `linux_connector/`: a Linux-side compatibility seed that can interoperate with a licensed Windows LoLa 2.0.0 XIMEA installation for control-plane negotiation and synthetic audio/video validation.

Open LoLa does not include the original LoLa application, installers, DLLs, source code, license files, or binary patches. Use it only with LoLa installations you are licensed to run.

## Why This Exists

We used LoLa in the RAPPLab project in 2022-2023 and saw the same pattern repeatedly: many universities and conservatories were already using LoLa successfully, while many others wanted to join but were Linux-native or Mac-native in their studios, labs, and teaching workflows.

The motivation for Open LoLa is to make that ecosystem more accessible: preserve compatibility with existing Windows LoLa sites, document the interoperability behavior, and work toward a future where Windows, Linux, and macOS users can LoLa together.

## Current Status

Implemented now:

- LoLa 2.0.0 XIMEA control-message parsing and generation.
- QuickConn/status/ACK/reject behavior with structured failure reasons.
- Audio and video media packet encode/decode.
- Synthetic diagnostic audio/video generation.
- Process-backed audio/video adapters for experiments.
- WSL lab tooling for validating against Windows LoLa.
- Packet-capture decoder and documentation.

Not production complete yet:

- Native low-latency Linux audio backends need production work.
- Native Linux camera/display backends need production work.
- macOS support is a project goal, not implemented in this first connector.
- LoLa 1.5/OSC15 compatibility should be treated as a separate compatibility effort.

## Quick Start

Run from the repository root:

```bash
python -m linux_connector.lola_connector.cli --local-ip 127.0.0.1 selftest --duration 0.25
```

Probe a licensed Windows LoLa peer:

```bash
python -m linux_connector.lola_connector.cli --local-ip <LINUX_LOLA_IP> status <WINDOWS_LOLA_IP>
```

Listen for Windows LoLa and transmit synthetic diagnostic media:

```bash
python -m linux_connector.lola_connector.cli \
  --local-ip <LINUX_LOLA_IP> \
  --sr 44100 --bps 16 --channels 2 \
  --fps 25 --bpp 8 --width 640 --height 480 --compression 0 \
  --audio-interval-scale 0.92 \
  listen --rx --test-media diagnostic --duration 20
```

## Validation Screenshots

Windows LoLa status check confirming the WSL/Linux connector replied:

![Windows LoLa status check against the WSL/Linux connector](linux_connector/docs/assets/lola-wsl-status-check.png)

Windows LoLa receiving the Linux diagnostic video card with Network Monitor counters showing complete audio/video reception:

![Windows LoLa diagnostic audio/video validation with Network Monitor counters](linux_connector/docs/assets/lola-wsl-diagnostic-av-validation.png)

## Documentation

Start at [linux_connector/docs/index.md](linux_connector/docs/index.md).

Key pages:

- [Quickstart](linux_connector/docs/quickstart.md)
- [WSL Lab Setup](linux_connector/docs/wsl-lab-setup.md)
- [Windows Validation](linux_connector/docs/windows-validation.md)
- [Protocol Reference](linux_connector/docs/protocol-reference.md)
- [Packet Capture](linux_connector/docs/packet-capture.md)
- [Troubleshooting](linux_connector/docs/troubleshooting.md)
- [Roadmap](linux_connector/docs/roadmap.md)
- [Legal Notes](LEGAL.md)

## Licensing And Original LoLa

The code in this repository is released under the MIT License.

The original LoLa software is separate licensed software from Conservatorio di Musica G. Tartini, developed in collaboration with GARR. The official LoLa site states that LoLa is available free for academic and education non-profit uses and shareware otherwise, and that users receive download credentials after submitting a signed license. See [LEGAL.md](LEGAL.md) for the project boundary and source notes.

Open LoLa is not affiliated with, endorsed by, or distributed by the original LoLa project, Conservatorio Tartini, or GARR.

## Repository Layout

- `linux_connector/`: Linux connector compatibility seed, docs, tests, tools, and WSL lab helpers.
- `LICENSE`: license for Open LoLa source code.
- `LEGAL.md`: original LoLa licensing/distribution boundary.
- `NOTICE`: attribution and naming notes.
- `pyproject.toml`: Python packaging metadata.

## Safety Boundary

Do not commit:

- original LoLa installers, executables, DLLs, manuals, license files, or extracted resources;
- private reverse-engineering artifacts;
- packet captures containing real network addresses or institution data;
- generated caches or local lab output.
