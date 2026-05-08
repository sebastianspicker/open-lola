# Windows Validation

Use this page as the live gate before calling an interop run successful.

Procedure type: same-machine WSL lab, real Linux host validation, or production-readiness work depending on the topology.

## Required Windows Settings

Use LoLa 2.0.0 XIMEA with settings matching the Linux command:

| Setting | Required starting value |
| --- | --- |
| Audio sample rate | `44100` |
| Audio bits | `16` |
| Audio channels | `2` |
| Video mode | raw/uncompressed, compression `0` |
| Video size | `640x480` |
| Video depth | `8` bit |
| Video FPS | `25` |
| Control port | `7000` |
| Audio port | `19788` |
| Video port | `19798` |

Windows LoLa must select the Npcap/WinPcap NIC that can see packets from Linux. Avoid loopback as a validation path.

## Linux Preflight

Procedure type: local self-test.

```bash
python -m linux_connector.lola_connector.cli --local-ip 127.0.0.1 selftest --duration 0.25
```

Then probe Windows LoLa:

```bash
python -m linux_connector.lola_connector.cli \
  --local-ip <LINUX_LOLA_IP> \
  status <WINDOWS_LOLA_IP>
```

Expected:

```text
status_ack=1
```

## Generated Bidirectional AV Test

Procedure type: same-machine WSL lab or real Linux host validation.

Initiate from Linux:

```bash
python -m linux_connector.lola_connector.cli \
  --local-ip <LINUX_LOLA_IP> \
  --sr 44100 --bps 16 --channels 2 \
  --fps 25 --bpp 8 --width 640 --height 480 --compression 0 \
  connect <WINDOWS_LOLA_IP> --rx --test-media diagnostic --duration 20
```

Or listen for Windows LoLa:

```bash
python -m linux_connector.lola_connector.cli \
  --local-ip <LINUX_LOLA_IP> \
  --sr 44100 --bps 16 --channels 2 \
  --fps 25 --bpp 8 --width 640 --height 480 --compression 0 \
  --audio-interval-scale 0.92 \
  listen --rx --test-media diagnostic --duration 20
```

Expected:

- Windows LoLa accepts QuickConn.
- Windows displays a moving diagnostic test card from Linux.
- Windows Network Monitor shows Linux-to-Windows audio/video receive activity.
- Linux prints nonzero `audio_rx` and `video_rx` when Windows is transmitting.

## Required Evidence

Control:

- `/MESG_CHECKLOLASTATUS` receives `/MESG_CHECKLOLASTATUS_ACK`.
- `/MESG_QUICKCONN` is followed by `/MESG_QUICKCONN_ACK`.
- Rejects only occur for explainable settings mismatches.

Linux to Windows audio:

- UDP source and destination port are both `19788`.
- UDP payload size is `1066`.
- Fragment count is `1`.
- Serialized PCM length is `256` for 2-channel, 64-frame, 16-bit audio.
- Fragment `frame_id` equals serialized `sequence + 1`.
- Windows incomplete audio packet counter stays at zero during the accepted run.

Linux to Windows video:

- UDP source and destination port are both `19798`.
- Each frame has one `0x40` video prelude before normal fragments.
- Raw 640x480x8 frame payload is `307200` bytes.
- Serialized frame size is `307208` bytes.
- Windows remote video displays the diagnostic test card.

Windows to Linux media:

- Linux runtime reports `audio_rx > 0` for Windows audio.
- Linux runtime reports `video_rx > 0` for Windows video, directly on a real network or via the WSL-only Npcap relay when required.
- Packet capture shows no unexplained sequence gaps for accepted audio.

## Real Linux Device Test

Procedure type: production-readiness work.

Example process-backed raw mode:

```bash
python -m linux_connector.lola_connector.cli \
  --local-ip <LINUX_LOLA_IP> \
  --sr 44100 --bps 16 --channels 2 \
  --fps 25 --bpp 8 --width 640 --height 480 --compression 0 \
  --audio-capture-cmd "ffmpeg -hide_banner -loglevel error -f pulse -i default -f s16le -ac 2 -ar 44100 -" \
  --audio-playback-cmd "ffplay -hide_banner -loglevel error -f s16le -ac 2 -ar 44100 -nodisp -" \
  --video-capture-cmd "ffmpeg -hide_banner -loglevel error -f v4l2 -video_size 640x480 -framerate 25 -i /dev/video0 -pix_fmt gray -f rawvideo -" \
  --video-display-cmd "ffplay -hide_banner -loglevel error -f rawvideo -pixel_format gray -video_size 640x480 -framerate 25 -" \
  connect <WINDOWS_LOLA_IP> --rx
```

Passing synthetic validation does not mean the production port is complete. Production readiness requires real Linux audio/video devices, low-jitter scheduling, and validation on the intended network hardware.

## Remaining Gaps

- Replace synthetic media with production Linux audio/video backends.
- Validate on a real Linux host over a physical or intentionally bridged NIC.
- Tune or replace the Python synthetic runtime if buffer `0` stability is required.
- Treat LoLa 1.5/OSC15 as a separate compatibility project.
