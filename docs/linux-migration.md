# Native Linux station and connector migration

The `rusty-lola` executable runs Windows and Linux sessions. On Linux it uses
ALSA for audio capture and playback and V4L2 for cameras. macOS keeps its own
Swift implementation, which connects directly to Rust peers. Python remains only
for repository tooling. The Python connector package, wheel, subprocess media
adapters, and WSL relay and deployment scripts are gone, with no compatibility
shim.

This page covers building the Linux station, running direct sessions, and the
Rust replacement for each retired Python command and option.

## Build and list devices

The target is Ubuntu 24.04 x86_64 with stable Rust. Install the system ALSA
runtime (`libasound2t64`), give the operator access to the audio and video
devices, and run from the repository root:

```bash
cargo build -p rusty-lola --release
cargo run -p rusty-lola -- devices
cargo run -p rusty-lola -- selftest --duration 0.25
cargo run -p rusty-lola -- ui
```

For a headless build, add `--no-default-features` before `--`; ALSA and V4L2
still work without egui. Windows defaults to PortAudio/ASIO and XIMEA, Linux
to ALSA and V4L2. Selecting a backend the platform does not support fails.
Diagnostic audio and video are synthetic and used only when selected.

ALSA devices are direct `hw` identifiers such as `hw:0,0`, and input and output
can differ. `default`, `plughw`, software mixing, and implicit resampling are
rejected. Rate, channels, sample encoding, and period must match what the
hardware accepts. See [ALSA validation](linux-alsa.md).

V4L2 takes `/dev/videoN` nodes, exact dimensions and frame rate, and the RGB3,
BGR3, YUYV, GREY, or MJPG formats. RGB3, BGR3, YUYV and MJPG produce RGB24 for
the raw or JPEG pipeline; GREY produces Mono8. Use `--bpp 24 --bayer 0` for
color and `--bpp 8 --bayer 0` for GREY. Inventory reports unsupported
capabilities, and multi-planar capture is rejected. See
[V4L2 capture](linux-v4l2.md).

## Direct sessions

Use fixed addresses on an isolated network. Replace the example addresses and
device identifiers with your own.

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

The listener's settings file must already exist and set the peer address
(`network.remote_ip`). Values apply in this order: defaults, settings file,
JSON/`.ssn` profile, command flags. The Linux default geometry may not suit
your camera, so check the inventory and select a mode it supports exactly. A
native format failure does not fall back to diagnostic media.

`status` only shows that the peer acknowledged a status request. Connecting,
sending, receiving, local preview, and a valid report each need checking
separately. `selftest` exchanges audio and video over localhost UDP on
OS-assigned ports; it does not exercise hardware or a reference peer.

## Retired Python commands and replacements

Python took its flags before the command. Rust operator flags go after
`connect` or `listen`; see each subcommand's `--help`.

| Former command or option | Rust replacement or retirement |
|---|---|
| `python -m linux_connector.lola_connector.cli` | `rusty-lola`; no importable Python runtime remains. |
| `status <remote_ip>` | `status <peer>`; `--local-ip`, `--sid`, `--timeout` kept. Rust defaults to SID 1 and a 1-second timeout; Python used 0 and 2 seconds. |
| `connect <remote_ip>`, `listen` | Same command names; set the listener's peer through `network.remote_ip` in its settings file. |
| `selftest --duration` | Same command; limited to 0.01–60 seconds. |
| `selftest --port-offset` | Retired; ephemeral ports keep concurrent tests apart. |
| `--local-ip`, `connect --sid` | Same flags, after the Rust subcommand; `--bind-ip` sets the socket binding separately. |
| `--sr`, `--bps`, `--channels`, `--audio-frames-per-callback` | Same flags; the station now opens the device in exactly that native format. |
| `--width`, `--height`, `--fps`, `--bpp`, `--bayer`, `--compression`, `--packet-size` | Same flags. `--compression` is 0 or 1. |
| `--control-dialect ascii/osc15` | Same values. `auto` is retired: select the peer's dialect. |
| `--source-name` | Retired; control messages are admitted by the configured peer address. |
| `--duration` | For a sustained session use `--continuous --duration N`. Rust `--frames` still works. |
| `--rx` | Python kept sending and printed RX metadata; the Rust `--rx` alias is receive-only. For media both ways, pass all four of `--tx-audio --rx-audio --tx-video --rx-video` or keep the default directions. Reports contain RX counters. |
| `--audio-capture-cmd`, `--audio-playback-cmd` | Retired; use `--audio-backend alsa`, `--input-device`, and `--output-device`. |
| `--video-capture-cmd`, `--video-display-cmd` | Retired; use `--camera-backend v4l2`, `--video-device`, `--pixel-format`, and the station's own preview. Headless runs do not start a display process. |
| `--max-frame-bytes` | Retired; the protocol has a fixed 16 MiB reassembly limit and a bounded fragment count. |
| `--audio-interval-scale` | Retired; native PCM periods and the audio scheduler set the timing. |
| `--test-media` | Use `--audio-backend diagnostic --camera-backend diagnostic`; `--test-signal-mode send/receive/both` selects the station's test signal. |
| `--tone-frequency`, `--tone-amplitude` | Retired; the station's test signal is a fixed 689/750 Hz sequence at −12 dBFS. |
| `--wait-for-remote-test-signal` | Retired; use receive-only streams in a bounded session and read the RX counters. |
| `--request-remote-audio-signal` | The default control extras send the test-signal request; `--no-extras` turns extras off. The native UI keeps its stream and test-signal controls. |
| `lola_packet_decoder.py <capture>` | `rusty-lola decode-pcap <capture>`: reads bounded PCAP/PCAPNG files and prints JSON summaries of fragments, preludes, endpoints and completeness, without Scapy. |

Nothing replaces the retired media subprocess options: there is no shell
command expansion and no external-executable layer. The WSL delivery
workarounds are not part of the native Linux station.

## Regression coverage

Before retirement, the Python suite passed 81 cases. Rust keeps the shared
25-case wire corpus and a 110-case ASCII/OSC15 acceptance corpus generated from
Python. Additional Rust tests cover:

- mixed OSC arguments, unsupported tags, and claimed-source rejection;
- malformed audio recovery, sequence wraparound and reordering;
- raw geometry admission and bounded fragment coverage;
- repeatable cleanup that keeps the first error;
- repeated bidirectional selftests.

The mixed OSC parser keeps wire values as sent, and the session still rejects
unsupported formats. Corrupt compressed images are dropped within bounds,
where Python accepted any compressed payload.

The Python packaging, import-graph, and subprocess tests were retired with the
code they tested. Substitute-API adapter tests, virtual-device cases, and
platform builds cover the replacements. Physical devices, reference peers, and
field latency need the separate procedures in [testing](testing.md).

Current software results and the checks still to run are in
[migration verification](linux-migration-verification.md).
