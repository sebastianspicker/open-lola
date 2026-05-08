# Quickstart

Use this page when you want to run the connector, check that the Python package works, or start a synthetic LoLa session.

Procedure type: local self-test, Windows peer smoke test, or real Linux host smoke test depending on the command.

## Run From The Package Parent

Commands assume the current directory is `<LOLA_PACKAGE_DIR>`, the directory that contains `linux_connector/`.

```bash
python -m linux_connector.lola_connector.cli --help
```

On Linux or WSL, `python3` may be the right executable:

```bash
python3 -m linux_connector.lola_connector.cli --help
```

## Local Self-Test

Procedure type: local self-test.

This validates the control handshake, audio/video media serialization, local UDP runtime path, and dependency-free test backends without Windows LoLa.

```bash
python -m linux_connector.lola_connector.cli --local-ip 127.0.0.1 selftest --duration 0.25
```

Expected result:

```text
endpoint_a=...
endpoint_b=...
```

The exact counters can vary, but both endpoints should report activity rather than crashing or timing out.

## Status Probe

Procedure type: Windows peer smoke test.

Use this when Windows LoLa is running and reachable on UDP control port `7000`.

```bash
python -m linux_connector.lola_connector.cli \
  --local-ip <LINUX_LOLA_IP> \
  status <WINDOWS_LOLA_IP>
```

Expected result:

```text
status_ack=1
```

If the result is `status_ack=0`, check Windows firewall, LoLa's `socketport`, and whether `<LINUX_LOLA_IP>` is the source IP Windows LoLa expects.

## Listen For Windows LoLa

Procedure type: Windows peer smoke test.

Use `listen` when Windows LoLa will initiate QuickConn to the Linux connector.

```bash
python -m linux_connector.lola_connector.cli \
  --local-ip <LINUX_LOLA_IP> \
  --control-dialect ascii \
  --sr 44100 --bps 16 --channels 2 \
  --fps 25 --bpp 8 --width 640 --height 480 --compression 0 \
  listen --rx
```

Windows LoLa must use matching audio settings. A mismatch in sample rate, bits per sample, or channel count causes a QuickConn rejection.

## Send Synthetic Audio/Video

Procedure type: Windows peer smoke test.

Use `diagnostic` to transmit synthetic audio plus a moving raw 640x480 8-bit video test card after connection.

```bash
python -m linux_connector.lola_connector.cli \
  --local-ip <LINUX_LOLA_IP> \
  --control-dialect ascii \
  --sr 44100 --bps 16 --channels 2 \
  --fps 25 --bpp 8 --width 640 --height 480 --compression 0 \
  --audio-interval-scale 0.92 \
  listen --rx --test-media diagnostic --duration 20
```

For audio-only isolation:

```bash
python -m linux_connector.lola_connector.cli \
  --local-ip <LINUX_LOLA_IP> \
  --control-dialect ascii \
  --sr 44100 --bps 16 --channels 2 \
  --audio-interval-scale 0.92 \
  listen --rx --test-media sine --duration 20
```

The `--audio-interval-scale 0.92` value was useful in the WSL lab. Re-measure it on a different host before treating it as a production default.

## Initiate QuickConn From Linux

Procedure type: Windows peer smoke test or real Linux host smoke test.

Use `connect` when Linux should initiate the session.

```bash
python -m linux_connector.lola_connector.cli \
  --local-ip <LINUX_LOLA_IP> \
  --control-dialect ascii \
  --sr 44100 --bps 16 --channels 2 \
  --fps 25 --bpp 8 --width 640 --height 480 --compression 0 \
  connect <WINDOWS_LOLA_IP> --rx --test-media diagnostic --duration 20
```

To ask Windows LoLa to send its built-in audio test signal during the run:

```bash
python -m linux_connector.lola_connector.cli \
  --local-ip <LINUX_LOLA_IP> \
  --sr 44100 --bps 16 --channels 2 \
  connect <WINDOWS_LOLA_IP> --rx --request-remote-audio-signal --duration 20
```

## Use Real Linux Media Through Process Backends

Procedure type: production-readiness work.

The current connector can pipe media through external commands. This is useful for experiments, but native low-latency backends are still future production work.

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

## Next Steps

- For same-machine Windows/WSL setup, read [WSL Lab Setup](wsl-lab-setup.md).
- For proof that a run passed, read [Windows Validation](windows-validation.md).
- For failing control or media, read [Troubleshooting](troubleshooting.md).
