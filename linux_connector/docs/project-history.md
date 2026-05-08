# Project History

This page is the condensed public history of the Linux connector bring-up. For current setup, validation, troubleshooting, and protocol details, start at [index.md](index.md).

Status date: 2026-05-07.

Status: working Windows LoLa 2.0 to Linux LoLa prototype for control-plane interop and synthetic bidirectional audio/video validation. It is not a production Linux LoLa application yet; native low-latency audio and video backends still need production work and target-hardware validation.

## Scope

The project goal was to make a Linux-side peer that can interoperate with a licensed Windows LoLa 2.0.0 XIMEA installation without distributing original LoLa code, binaries, installers, manuals, license files, or binary patches.

The validated prototype does four things:

- accepts and initiates LoLa 2.0 control sessions;
- serializes and parses audio/video media packets;
- sends synthetic Linux audio/video to Windows LoLa;
- receives and decodes Windows-originated test audio/video in the WSL lab path.

The public repo keeps only independently written connector code, reproducible commands, sanitized behavioral notes, and validation screenshots. Raw reverse-engineering output, extracted strings, packet captures, binaries, and private lab artifacts stay out of Git.

## Timeline

### 2023

The connector started as a Linux interoperability experiment for institutions that already used LoLa but wanted Linux-native or Mac-native workflows in studios, labs, and teaching spaces.

### 2024

The work shifted from ad hoc probing toward protocol-level documentation: control messages, media ports, packet structure, and validation procedure.

### 2025

The Linux runtime shape became clear:

- a protocol core for control and media serialization;
- an async connector for QuickConn/status/listen/connect;
- a runtime that pumps audio/video between a session and backend interfaces;
- synthetic and process-backed media backends for validation before native device work.

### 2026-05-07

The Windows/WSL lab proved the current prototype:

- Windows LoLa 2.0 connects to the Linux connector in WSL.
- Linux sends synthetic audio to Windows LoLa.
- Linux sends synthetic raw video to Windows LoLa.
- Windows sends test audio packets that Linux receives and decodes.
- Windows or LoLa Tester sends video packets that Linux receives and decodes; one WSL path needs the Npcap-to-Winsock relay.
- Audio packet structure is understood well enough for complete Windows RX counters in the validated timing path.

## Reverse-Engineering Boundary

The public method is behavior-first:

1. Inspect strings, imports, and cross-references only to locate externally visible behavior.
2. Recover control-message names, media ports, packet fields, and session flow.
3. Validate every inferred field against packet captures and runtime counters.
4. Publish only behavioral summaries and independently written implementation.

Do not publish copied decompiler output, proprietary source reconstruction, binary excerpts, raw packet dumps, extracted resources, installers, manuals, license files, or private environment artifacts.

Useful public hypotheses that were validated:

| Behavior | Evidence class |
| --- | --- |
| LoLa 2.0 ASCII control uses padded UDP datagrams on port `7000` | Live control messages and parser round trips |
| QuickConn carries audio/video settings | Live accept/reject behavior |
| Media ports are `19788` for audio and `19798` for video | Packet captures and Windows adapter behavior |
| Audio uses one normal LoLa fragment per 64-frame callback | Packet parsing and Windows Network Monitor counters |
| Accepted audio uses `frame_id = sequence + 1` | Before/after incomplete-packet validation |
| Raw video uses a prelude plus normal fragments | Packet parsing and frame reassembly |
| WSL can need a relay for Windows/Npcap-injected media | Windows Npcap versus WSL tcpdump comparison |

## Known-Good Lab Shape

The reproducible WSL validation used:

```text
Windows WSL adapter IP: 172.24.144.1
WSL/Linux IP:          172.24.159.30
control port:          7000
audio port:            19788
video port:            19798
audio:                 44100 Hz, 16-bit, 2 channels
video:                 640x480, 8-bit, 25 FPS, raw
```

The Windows-side LoLa settings must match the Linux connector. The relevant shapes are:

```ini
[Audio]
InputAudioDevName=FlexASIO
OutputAudioDevName=FlexASIO
SamplingRate=44100.000000
NumOfChannels=2
bitPerSample=16

[Video]
FrameRate=25.000000
bitPerPixel=8
FrameX=640
FrameY=480
Compression=0

[Network]
socketport=7000
audioport=19788
videoport=19798
VideoTxWinPcap=1
AudioTxFixedBuffer=1
NicDevName=<NPCAP_ADAPTER_GUID>;;
RxPacketFiltering=1
VideoPacketSize=1000
```

```ini
[RemoteHost]
RemoteIpAddr=172.24.159.30;0.0.0.0;

[AVBuffers]
RemoteVideoBuffers=0;0;
RemoteAudioBuffers=8;1;
```

In the validated WSL path, remote audio buffer `8` was stable. Buffer `0` was too strict for that timing path.

## Minimal Reproduction

Run from the directory that contains `linux_connector/`.

Local self-test:

```bash
python -m linux_connector.lola_connector.cli --local-ip 127.0.0.1 selftest --duration 0.25
```

Status probe against Windows LoLa:

```bash
python -m linux_connector.lola_connector.cli \
  --local-ip 172.24.159.30 \
  status 172.24.144.1
```

Listen for Windows LoLa and transmit diagnostic synthetic media:

```bash
python -m linux_connector.lola_connector.cli \
  --local-ip 172.24.159.30 \
  --control-dialect ascii \
  --sr 44100 --bps 16 --channels 2 \
  --fps 25 --bpp 8 --width 640 --height 480 --compression 0 \
  --audio-interval-scale 0.92 \
  listen --rx --test-media diagnostic --duration 20
```

## Validation Summary

The prototype was considered working when these checks passed:

| Gate | Accepted evidence |
| --- | --- |
| Control connect | Windows LoLa reaches Linux and receives QuickConn ACK |
| Linux-to-Windows audio | Windows Network Monitor counts Audio RX frames and incomplete packets stay at zero |
| Linux-to-Windows video | Windows displays the moving diagnostic raw test card |
| Windows-to-Linux audio | Linux decodes complete 1066-byte audio packets with expected PCM length |
| Windows-to-Linux video | Linux reassembles video frames directly or through the documented WSL relay workaround |
| Packet shape | Audio `frame_id = sequence + 1`; video prelude plus complete fragments |

## Implemented File Map

| File | Role |
| --- | --- |
| `lola_connector/protocol.py` | LoLa control datagram parser/builder |
| `lola_connector/media.py` | Audio/video payload serialization, fragmentation, and reassembly |
| `lola_connector/connector.py` | QuickConn/status/listen/connect and fixed media source ports |
| `lola_connector/runtime.py` | Async audio/video/control runtime loops |
| `lola_connector/backends.py` | Synthetic, memory, and subprocess media backend interfaces |
| `lola_connector/selftest.py` | Local control and bidirectional UDP runtime self-tests |
| `tools/lola_packet_decoder.py` | Offline pcap decoder for media fragments and video preludes |
| `env/npcap_udp_relay.py` | WSL lab relay for Npcap-visible packets not delivered into WSL |

## Limits

This is still a protocol/runtime prototype.

Not done yet:

- production JACK/PipeWire/ALSA audio capture and playback;
- production V4L2/GStreamer video capture and display;
- real Linux host validation on intended network hardware;
- a user-facing production UI/config surface;
- broader LoLa 1.5/OSC15 compatibility validation.

For the current work queue, use [roadmap.md](roadmap.md). For current completion state, use [status.md](status.md).
