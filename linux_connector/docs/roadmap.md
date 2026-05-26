# Roadmap

Use this page when continuing the Linux port beyond the validated compatibility seed.

Procedure type: production-readiness work.

## Current Implemented Slice

Implemented now:

- LoLa 2.0.0 XIMEA control-plane compatibility.
- Audio/video payload codec.
- Optional raw Ethernet frame builder.
- Runtime pump between connector and media backends.
- Dependency-free synthetic and memory test backends.
- Generic subprocess backends for real Linux I/O experiments.
- Live Windows LoLa 2.0 WSL validation with bidirectional synthetic audio/video.

## Native Backend Targets

Audio:

- Preferred low-latency backend: JACK or PipeWire JACK API.
- Fallback backend: ALSA through `sounddevice`/PortAudio or direct ALSA.
- Required LoLa block size: 64 frames.
- Required format: interleaved PCM matching negotiated sample rate, bits, and channel count.

Video:

- Capture backend: V4L2 or GStreamer.
- Raw mode: emit frame bytes matching negotiated width, height, and bits per pixel.
- Compressed mode: emit JPEG bytes or add a JPEG encoder path.
- Display backend: SDL, Qt, GTK, OpenCV, or GStreamer sink.

Networking:

- Default: normal UDP sockets with source ports fixed to LoLa audio/video ports.
- Advanced fallback: AF_PACKET/libpcap TX using `lola_connector/ethernet.py` if a target Windows LoLa path requires pcap-visible raw frames with exact outer headers.

## MVP Run Modes

The production port should preserve these run modes:

- `listen`: Linux waits for Windows LoLa QuickConn, ACKs compatible settings, then starts media runtime.
- `connect`: Linux sends QuickConn to Windows LoLa, waits for ACK/reject, then starts media runtime.
- `selftest`: no peer; validates codec and backend block/frame generation.

## Done Definition For A Full Port

- Control session can connect and disconnect with Windows LoLa.
- Linux audio capture transmits to Windows LoLa.
- Windows LoLa audio is played locally on Linux.
- Linux video capture transmits to Windows LoLa.
- Windows LoLa video is displayed locally on Linux.
- Raw and JPEG video modes are validated.
- Packet capture confirms sequence numbers, one-fragment audio, video prelude, and complete video reassembly.
- UI or config exposes local IP, remote IP, audio device, video device, audio buffers, video packet size, compression, and dimensions.
- Validation passes on intended network hardware, not only the same-machine WSL lab.

## Compatibility Notes

Treat LoLa 1.5/OSC15 as a separate compatibility project. The final working path documented here is LoLa 2.0 ASCII control.
