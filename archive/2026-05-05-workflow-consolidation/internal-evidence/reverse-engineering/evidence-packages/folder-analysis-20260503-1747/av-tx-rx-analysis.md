# AV TX/RX Focus Analysis

## Audio

- Classification: confirmed. `LolaGui_XIMEA_x64.exe` imports `portaudio_x64.dll` and contains ASIO setup/error strings, audio device keys, audio channel/sample-rate mismatch diagnostics, local/remote WAV recording names, and audio RX/drop/realign counters.
- Classification: inferred. The design is callback/buffer oriented and prioritizes small ASIO buffers. The warning string explicitly says LoLa requires 32 or 64 sample audio-card buffers.
- Classification: requires validation. Exact callback scheduling, clock source, underrun policy, and 44.1 kHz versus 48 kHz runtime selection need Windows hardware measurement.

## Video

- Classification: confirmed. The main GUI imports XIMEA (`xiGetImage`, `xiOpenDevice`, `xiStartAcquisition`, `xiSetParam*`), OpenCV 2.4.9, GDI/D2D/DWrite, and IJG JPEG.
- Classification: observed. Camera profile files encode Mono8/RGB24 profiles, explicit resolutions, and high-FPS presets. `XimeaColors.ini` stores white-balance/color correction defaults.
- Classification: inferred. The primary live v2.0 camera path is XIMEA capture -> local preview/frame buffers -> raw or CPU MJPEG video TX -> receive/decode/display/recording.
- Classification: requires validation. Exact frame queue depth, drop policy, and camera timing require hardware execution.

## Codecs

- Classification: confirmed. CPU JPEG is active at package/import/string level through `jpeg62.dll` and `M-JPEG (CPU)` strings.
- Classification: confirmed. GPUJPEG is present as a CUDA-backed DLL with exported encode/decode APIs.
- Classification: inferred. GPUJPEG is not statically linked by the v2.0 main GUI, so it is likely retained package lineage or dynamically optional rather than the primary v2.0 live codec.

## Network And Session

- Classification: confirmed. The primary GUI links WinPcap and Winsock/IP Helper. It contains `pcap_sendpacket`, sendqueue, receive/filter functions, raw IP/UDP filter strings, ARP/ICMP support, and plaintext `/MESG_*` control templates.
- Classification: observed. Session setup strings carry A/V format fields: sample rate, bits per sample, channels, FPS, bits per pixel, frame dimensions, compression, and Bayer flag.
- Classification: inferred. Control/session messages appear separate from high-rate audio/video packet paths; media is packetized over WinPcap/raw UDP-like framing.
- Classification: requires validation. No runtime packet capture was performed, so exact Ethernet/IP/UDP headers, payload grammar, sequencing, and retransmission/drop semantics remain unknown.

## Low-Latency Design Hints

- 32/64 sample ASIO buffer warning.
- WinPcap `setmintocopy`, BPF filtering, and sendqueue usage.
- Separate audio/video ports and explicit packet-size configuration.
- Audio/video dropped/incomplete/realigned counters.
- CPU MJPEG and raw video paths rather than general-purpose streaming protocols.
