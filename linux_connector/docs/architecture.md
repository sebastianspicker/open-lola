# Architecture

Use this page to understand how the connector is structured.

Procedure type: reference.

## Package Layers

The connector is intentionally split into layers:

| Layer | Responsibility |
| --- | --- |
| Protocol core | Build and parse control messages, media serialization, media fragments, and optional Ethernet/IPv4/UDP frames |
| Session connector | Initiate or accept QuickConn, send status/chat/disconnect, manage fixed source-port media sockets |
| Runtime | Pump media between a connected LoLa session and audio/video backends |
| Backends | Provide synthetic, memory, subprocess, and future native Linux audio/video sources and sinks |
| CLI/tools | Exercise the connector, run self-tests, and decode captures |

## Main Modules

| Module | Responsibility |
| --- | --- |
| `lola_connector/protocol.py` | `/MESG_*` control datagrams, ASCII LoLa 2.0 behavior, OSC15 compatibility work |
| `lola_connector/media.py` | Audio/video serialization, normal fragments, audio packets, video preludes, reassembly |
| `lola_connector/connector.py` | Sessions, QuickConn/status/connect/disconnect, fixed media source ports |
| `lola_connector/runtime.py` | Async audio/video TX/RX loops, synthetic pacing, backend plumbing |
| `lola_connector/backends.py` | Synthetic sources, memory sinks, and process-backed adapters |
| `lola_connector/ethernet.py` | Optional raw Ethernet/IPv4/UDP frame construction |
| `lola_connector/selftest.py` | Local control and bidirectional runtime tests |
| `tools/lola_packet_decoder.py` | Offline pcap decoder for LoLa media fragments and video preludes |
| `deployment/wsl/npcap_udp_relay.py` | WSL lab relay for Npcap-visible packets not delivered into WSL |

## CLI Modes

The CLI entry point is:

```bash
python -m linux_connector.lola_connector.cli
```

Available modes:

| Mode | Purpose |
| --- | --- |
| `selftest` | Run local control and bidirectional UDP runtime tests |
| `status` | Send `/MESG_CHECKLOLASTATUS` and wait for ACK |
| `listen` | Accept one incoming Windows LoLa QuickConn |
| `connect` | Initiate QuickConn to a Windows LoLa host |

Important shared options:

- `--local-ip`
- `--sr`
- `--bps`
- `--channels`
- `--fps`
- `--bpp`
- `--width`
- `--height`
- `--compression`
- `--packet-size`
- `--control-dialect`
- `--audio-capture-cmd`
- `--audio-playback-cmd`
- `--video-capture-cmd`
- `--video-display-cmd`
- `--audio-frames-per-callback`
- `--audio-interval-scale`

Synthetic media choices for `listen` and `connect`:

- `silence`
- `sine`
- `tones`
- `diagnostic`

## Backend Boundary

The connector boundary is ready for real Linux media adapters:

- feed 64-frame interleaved PCM blocks into audio TX;
- consume received PCM blocks from audio RX;
- feed raw or JPEG frame bytes into video TX;
- consume received raw or JPEG frame bytes from video RX.

The current process-backed adapters are useful for experiments. Native JACK/PipeWire/ALSA/V4L2/GStreamer or GUI-integrated backends remain roadmap work.

## What This Is Not Yet

This package is not a full LoLa GUI and not a production Linux audio/video application yet. It is a protocol/runtime harness that proves interoperability and provides a clean boundary for the production media layer.
