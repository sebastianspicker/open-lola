# Native Linux station and connector migration

The `rusty-lola` executable now owns Windows and Linux sessions. Linux uses ALSA
capture/playback and V4L2 cameras, while macOS remains an independent Swift
implementation that connects directly to Rust peers. Python is retained only for
repository tooling: the connector package, wheel, subprocess media adapters, and
WSL relay and deployment scripts are retired without a shim.

Use this document to build the Linux station, run direct sessions, and find the
replacement for a retired Python connector command or option.

## Build and discover

The software target is Ubuntu 24.04 x86_64 with stable Rust. Install the
system ALSA runtime (`libasound2t64`), grant the operator access to the selected
audio/video devices, and run from the repository root:

```bash
cargo build -p rusty-lola --release
cargo run -p rusty-lola -- devices
cargo run -p rusty-lola -- selftest --duration 0.25
cargo run -p rusty-lola -- ui
```

Use `--no-default-features` before `--` for a headless build. ALSA and V4L2
remain available without egui. Windows keeps PortAudio/ASIO and XIMEA defaults;
Linux defaults select ALSA and V4L2. An explicitly unsupported backend fails.
Diagnostic audio/video must be selected explicitly and is always synthetic.

ALSA device names are direct `hw` identifiers such as `hw:0,0`; input and
output can differ. `default`, `plughw`, software mixing, and implicit
resampling are rejected. Rate, channels, sample encoding, and period must
match the hardware's negotiated values. See [ALSA validation](linux-alsa.md).

V4L2 accepts `/dev/videoN` nodes, exact dimensions/FPS, and RGB3, BGR3, YUYV,
GREY, or MJPG formats. RGB/BGR/YUYV/MJPG produce RGB24 for the existing raw or
JPEG pipeline; GREY produces Mono8. Select `--bpp 24 --bayer 0` for color or
`--bpp 8 --bayer 0` for GREY. Inventory reports unsupported capabilities;
multi-planar capture is rejected explicitly. See [V4L2 validation](linux-v4l2.md).

## Direct sessions

Configure explicit addresses on an isolated network. Replace the example
addresses and device identifiers with the selected interfaces and devices.

```bash
cargo run -p rusty-lola -- listen --local-ip 192.0.2.20 \
  --bind-ip 192.0.2.20 --settings /tmp/station.json \
  --input-device hw:0,0 --output-device hw:0,0 \
  --video-device /dev/video0 --pixel-format YUYV \
  --width 640 --height 480 --fps 30 --bpp 24 --bayer 0 \
  --continuous --duration 10
cargo run -p rusty-lola -- status 192.0.2.20 --local-ip 192.0.2.10
cargo run -p rusty-lola -- connect 192.0.2.20 --local-ip 192.0.2.10 \
  --bind-ip 192.0.2.10 --continuous --duration 10
```

The settings file in the listener example must already exist and contain its
configured peer address (`network.remote_ip`). Defaults are overlaid by
settings, then a JSON/`.ssn` profile, then explicit command flags. Linux
default geometry may not match a particular camera: use inventory and select
an exact supported mode. Native format failures do not start diagnostic media.

`status` proves only a matching status acknowledgement. A connection, TX,
RX, local preview, and validated report are separate observations. The
`selftest` exchanges audio and video over isolated localhost UDP with
OS-assigned ports; it proves neither hardware nor reference-peer operation.

## Retired Python commands and replacements

Python flags were global before the command. Rust operator flags follow
`connect` or `listen`; use subcommand `--help` for their syntax.

| Former command or option | Rust replacement or retirement |
|---|---|
| `python -m linux_connector.lola_connector.cli` | `rusty-lola`; no importable Python runtime remains. |
| `status <remote_ip>` | `status <peer>`; `--local-ip`, `--sid`, `--timeout` retained. Rust defaults SID 1 and timeout 1 second; Python used 0 and 2 seconds. |
| `connect <remote_ip>`, `listen` | Same command names; set the listener peer through `network.remote_ip` in its settings file. |
| `selftest --duration` | Same command; bounded 0.01–60 seconds. |
| `selftest --port-offset` | Retired; ephemeral ports isolate concurrent tests. |
| `--local-ip`, `connect --sid` | Same flags after the Rust subcommand; `--bind-ip` independently chooses socket binding. |
| `--sr`, `--bps`, `--channels`, `--audio-frames-per-callback` | Same operator flags; exact native format negotiation replaces process stream assumptions. |
| `--width`, `--height`, `--fps`, `--bpp`, `--bayer`, `--compression`, `--packet-size` | Same operator flags. `--compression` is 0 or 1. |
| `--control-dialect ascii/osc15` | Same values. `auto` is retired: explicitly select the peer dialect. |
| `--source-name` | Retired; control source identifies the configured peer address for admission checks. |
| `--duration` | For a sustained lifecycle use `--continuous --duration N`. Existing Rust `--frames` behavior remains available. |
| `--rx` | Python retained TX and printed RX metadata. Rust's existing alias is receive-only. For bidirectional media use all four `--tx-audio --rx-audio --tx-video --rx-video` flags or the default directions. Reports contain RX counters. |
| `--audio-capture-cmd`, `--audio-playback-cmd` | Retired; select `--audio-backend alsa`, `--input-device`, and `--output-device`. |
| `--video-capture-cmd`, `--video-display-cmd` | Retired; select `--camera-backend v4l2`, `--video-device`, `--pixel-format`, and the station's native preview. Headless runs do not launch a display process. |
| `--max-frame-bytes` | Retired as an operator override; the protocol has a fixed 16 MiB reassembly ceiling and bounded fragment count. |
| `--audio-interval-scale` | Retired; native PCM periods and the audio scheduler determine cadence. |
| `--test-media` | Explicit `--audio-backend diagnostic --camera-backend diagnostic`; `--test-signal-mode send/receive/both` selects the station's existing test signal policy. |
| `--tone-frequency`, `--tone-amplitude` | Retired custom generator knobs; station test signals use its documented 689/750 Hz, −12 dBFS sequence. |
| `--wait-for-remote-test-signal` | Retired implicit wait mode; use receive-only streams and inspect observed RX counters in a bounded session. |
| `--request-remote-audio-signal` | Existing control extras send the test-signal request; `--no-extras` disables extras. Native UI retains explicit stream/test controls. |
| `lola_packet_decoder.py <capture>` | `rusty-lola decode-pcap <capture>`; bounded PCAP/PCAPNG, JSON fragment/prelude/endpoint/completeness summaries, no Scapy dependency. |

No shell-command expansion or executable compatibility layer replaces the
retired media subprocess options. WSL delivery workarounds are not part of
the native Linux station.

## Regression and evidence boundary

Before retirement, the Python suite passed 81 cases. Rust retains the shared
25-case wire corpus and a Python-generated 110-case ASCII/OSC15 acceptance
corpus. Further Rust regressions cover mixed OSC arguments, unsupported tags,
claimed-source rejection, malformed audio recovery, sequence wrap and
reordering, raw geometry admission, bounded fragment coverage, idempotent
cleanup with primary-error preservation, and repeated bidirectional selftests.
The mixed OSC parser preserves wire values, and session policy still rejects
unsupported formats. Corrupt compressed images are bounded drops, replacing
Python's opaque compressed-payload acceptance.

Python packaging/import-graph and subprocess execution tests retired with
their implementation. Native adapter substitute tests, virtual-device cases,
and platform builds cover their replacements. Physical devices, reference
peers, and field latency require the separate procedures and evidence in
[testing](testing.md); software tests do not establish those claims.

Current software results and remaining execution lanes are recorded in
[migration verification](linux-migration-verification.md).
