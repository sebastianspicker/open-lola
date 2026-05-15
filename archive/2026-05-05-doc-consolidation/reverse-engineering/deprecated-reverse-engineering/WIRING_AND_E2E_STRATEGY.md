# Reverse Engineering: Wiring And E2E Strategy

Back to index: [README.md](../README.md)

Scope: static synthesis across `../win-compiled/1-5` and
`../win-compiled/2-0`. This file connects the artifact inventory, protocol
surface, audio workflow, and video workflow. It does not claim runtime proof
where only strings, imports, or disassembly were available.

## Component Wiring Summary

| Component | Static fact | Role in LoLa |
|---|---|---|
| MFC GUI and settings | `LolaGui_XIMEA_x64.exe` imports MFC, Win32 UI APIs, profile INI APIs, dialogs, menus, and resources. | Owns setup dialogs, session state, chat, recording setup, activation dialog, and per-session control pages. |
| Activation and host identity | Strings reference `TartiniLola`, `LOLAGUI`, `Serial`, CPU registry keys, and BIOS registry keys. | Stores or validates user/serial data and reads host metadata. The validation algorithm was not reconstructed. |
| Audio hardware | The main GUI imports PortAudio ordinals and uses `PaAsio_GetAvailableBufferSizes`. | ASIO-first full-duplex audio path with 64-frame signed 16-bit PCM callback blocks. |
| Camera hardware | The main GUI imports `xiapi64.dll` functions including `xiOpenDevice`, `xiSetParam*`, and `xiGetImage`. | XIMEA capture, ROI, exposure, image format, and color-correction setup. |
| Video image processing | The main GUI imports OpenCV 2.4.9, IJG/libjpeg, GDI, and display functions. | Bayer/color conversion, raw or MJPEG video handling, display, and image recording. |
| Network transport | The main GUI imports WinPcap, Winsock, and IP Helper APIs. | WinPcap sends and receives LoLa audio/video packets; Winsock/IP Helper support reachability, address, and control setup. |
| Recording utilities | `LolaVideoConverter_x64.exe` and `LolaWavSplitter_x64.exe` are byte-identical across v1.5 and v2.0. | Offline conversion and WAV splitting, not live transport. |
| Tester | `LolaGui_TESTER_x64.exe` is byte-identical across v1.5 and v2.0 and says it is based on LoLa 1.3.0. | Test/emulation surface for network/session behavior, not the current XIMEA hardware lineage. |
| Corpus packaging | Full corpus inventory classifies 100 non-`.DS_Store` files: LoLa apps/helpers, third-party runtimes, vendor installers, and camera/config payloads. | v2.0 is an assembled distribution, not a same-day rebuild of every shipped component. |

## Heavy Static Refresh

Ghidra headless added import-caller and decompiler-signal evidence for the main
component boundaries:

| Surface | Evidence label | Ghidra caller clusters |
|---|---|---|
| Audio setup/open | Static fact | `FUN_140007980`, `FUN_140009010`, and `FUN_1400093a0` resolve PortAudio initialization, ASIO buffer probing, and `Pa_OpenStream`. |
| Audio send | Static fact | `FUN_140009bf0` resolves `WaitForSingleObject`, `SetEvent`, `pcap_sendpacket`, `0x2a`, and `0x21`. |
| Network/session setup | Static fact | `FUN_140016f20` opens WinPcap, sets min-copy, compiles/sets BPF filters, and starts RX; `FUN_140020660`, `FUN_1400205b0`, and `FUN_14002b650` cover adapter, ARP, and ICMP reachability helpers. |
| Audio control/settings | Static fact | `FUN_14001fb60` builds quick-connect, reject, disconnect, chat, bounce-back, and generated-audio-signal messages; `FUN_14001f390` parses them; `FUN_14002a6e0` loads and `FUN_140031d70` saves the audio/network/session settings. |
| XIMEA camera | Static fact | `FUN_14000fb40` and `FUN_140012ec0` resolve XIMEA open/config/start/image calls and capture-loop image retrieval. |
| Video encode/send | Static fact | `FUN_1400115c0` resolves raw WinPcap send queues; `FUN_140011c10` resolves IJG/libjpeg compression plus WinPcap send queues. |
| Receive/reassembly side | Strong inference | `FUN_1400152d0` resolves `pcap_next_ex`, IJG/libjpeg decompression, counters, and event signaling; address-level objdump still carries the detailed audio/video branch split. |
| Display | Static fact | `FUN_140019c80` resolves `CreateDIBSection`; `FUN_14001ac90` resolves `CreateCompatibleDC`, `SetDIBColorTable`, and `StretchBlt`. |
| CUDA branch boundary | Static fact | v1.5 CUDA resolves `gpujpeg_*` callers in encode/decode clusters; v2.0 main has GPUJPEG strings but no GPUJPEG import/caller cluster. |
| Whole corpus roles | Static fact | Corpus-origin Ghidra runs across all 9 LoLa-owned executables/helpers show the tester as an older emulation/control surface, converter as offline JPEG/OpenCV utility, and splitter as offline WAV utility. |

This does not change the ethical/runtime boundary. It improves static
confidence, but it is still not a live packet capture, hardware timing run, or
activation analysis.

## Corpus Integration

Static fact:

- `LolaGui_XIMEA_x64.exe` is the active v2.0 live GUI tying together MFC UI,
  settings/session files, registry serial/user state, ASIO/PortAudio, XIMEA,
  OpenCV/IJG/GDI, WinPcap, Winsock, and IP Helper APIs.
- `LolaGui_TESTER_x64.exe` is byte-identical in v1.5 and v2.0 and preserves
  older OSC/socket class strings plus `/MESG_ACCEPT` and
  `/MESG_BOUNCEBACKCONN`.
- `LolaVideoConverter_x64.exe` is byte-identical in v1.5 and v2.0, exposes
  OpenCV/IJG conversion and preview strings, and has no XIMEA, WinPcap,
  PortAudio, or GPUJPEG live-transport import surface.
- `LolaWavSplitter_x64.exe` is byte-identical in v1.5 and v2.0, exposes WAV
  splitting/conversion UI strings, and has no live transport surface.
- v2.0 retains byte-identical PortAudio, OpenCV 2.4.9, IJG/libjpeg, GPUJPEG,
  CUDA runtime, WinPcap installer, XIMEA installer, and XIMEA runtime files
  from matching v1.5 paths.

Strong inference:

- The shipped product shape is one live GUI, one older tester/emulator, two
  offline post-processing helpers, vendor runtimes/installers, and camera/config
  payloads.
- v2.0's visible architecture change is concentrated in the main GUI,
  semicolon/key-value session control, expanded XIMEA camera support,
  `XimeaColors.ini`, and newer VC runtime DLLs.

## Evidence Levels

| Level | Meaning in these docs |
|---|---|
| Static fact | Directly visible in PE headers, imports, resources, strings, hashes, or disassembly. |
| Strong inference | Multiple static facts point to one workflow, for example imports plus strings plus call shape. |
| Medium inference | Static evidence is real, but the semantic label or branch coverage is not fully proven. |
| Runtime gap | Requires Windows execution, packet capture, XIMEA/ASIO hardware, or a LoLa peer. |

## Control And Chat E2E

Static fact:

- v2.0 embeds plaintext control/chat format strings with `SRCIP`, `DSTIP`, and
  `SID`.
- `/MESG_CHAT`, `/MESG_QUICKCONN`, `/MESG_DISCONNECT`, bounce-back toggles, and
  generated audio-signal commands are all visible in the main v2.0 GUI.
- `FUN_14001fb60` formats `/MESG_QUICKCONN`, `/MESG_QUICKCONN_ACK`,
  `/MESG_REJECT`, `/MESG_DISCONNECT`, `/MESG_CHAT`,
  `/MESG_SWITCH_ON_BB`, `/MESG_SWITCH_OFF_BB`,
  `/MESG_SEND_AUDIO_SIGNAL`, and `/MESG_STOP_AUDIO_SIGNAL`; `FUN_14001f390`
  parses/dispatches the matching message names.
- v2.0 imports `getaddrinfo`, `freeaddrinfo`, `getnameinfo`, and `inet_pton`
  from Winsock; IP Helper caller evidence covers `GetAdaptersInfo`, `SendARP`,
  `IcmpCreateFile`, `IcmpSendEcho`, and `IcmpCloseHandle`.
- `FUN_140016f20` proves the media RX open path: `pcap_findalldevs`,
  `pcap_open`, `pcap_setmintocopy`, `pcap_compile`, and `pcap_setfilter`
  around `ip and udp` or host/port-specific BPF filters.
- `LolaGui.ini` loader defaults are `socketport=7000`, `audioport=19788`,
  `videoport=19798`, `WinPcap_SetMinToCopy=10`, and `RxPacketFiltering=1`.
- v1.5 uses a different-looking message vocabulary without the v2.0
  semicolon/key-value format and also exposes OSC-related parser strings.

Strong inference:

- v2.0 moved toward explicit multi-session control because it embeds `SID:%d`,
  `Session 1` through `Session 4` UI/resource evidence, and per-session monitor
  strings.
- The chat/control channel is plaintext at the application-message layer.
- End-to-end session flow is settings/NIC selection, address/reachability
  checks, status check/ACK, quick connect/ACK or reject, active WinPcap media,
  optional chat/bounce-back/generated-signal/monitor traffic, then disconnect.

Runtime gap:

- The exact socket or packet path for each control message still needs live
  tracing. The embedded strings prove message formats, not a complete wire
  grammar.
- Text escaping, retry/timeout policy, and byte-for-byte control framing remain
  unproven.

## Network TX/RX E2E

Static fact:

- Audio TX (`FUN_140009bf0`) calls the shared LoLa fragment/raw frame path and
  sends with `pcap_sendpacket`.
- Raw video TX (`FUN_1400115c0`) and MJPEG TX (`FUN_140011c10`) use
  `pcap_sendqueue_alloc`, `pcap_sendqueue_queue`, `pcap_sendqueue_transmit`,
  and `pcap_sendqueue_destroy`.
- The shared fragment/message helper `FUN_1400070b0` is called by audio, raw
  video, and MJPEG send paths and contains `0x21` header arithmetic plus the
  `0xeeeeeeee` marker write.
- The shared raw Ethernet/IPv4/UDP builder `FUN_140020ba0` is called by audio
  and video send paths and contains payload offset `0x2a` and IPv4 identifier
  constant `0x1337`.
- RX (`FUN_1400152d0`) calls `pcap_next_ex`, reassembly helpers, JPEG decode
  where needed, event signaling, counters, and display/recording handoffs.
- The single-packet helper `FUN_140020d70` opens a WinPcap device, calls
  `pcap_sendpacket`, and closes it; the recovered graph shows no normal incoming
  callers.

Strong inference:

- LoLa's media transport is a custom low-latency packet layer above raw
  Ethernet/IPv4/UDP construction, not ordinary application-level `sendto` for
  the latency-critical audio/video payloads.
- RX is drop/realign/continue oriented: counters track incomplete, dropped,
  orphaned, and realigned media instead of implying retransmission.

Runtime gap:

- Exact media fragment grammar, marker semantics, packet loss behavior, and
  whether `FUN_140020d70` is dead/debug/indirectly used need runtime or deeper
  data-flow proof.

## Audio E2E Strategy

Static fact:

- The recovered PortAudio open path uses full-duplex callback mode, signed
  16-bit PCM, 64 frames per callback, and a `44100.0` constant.
- The callback publishes one capture block and signals `WriteEvent`; it does
  not wait for network, UI, recording, or disk I/O.
- Local callback work is simple signed-16-bit capture/monitor gain scaling,
  ping-pong capture buffering, remote ring copy/clear/advance, and optional
  recording-ring copy.
- The send thread serializes `uint32 sequence`, `uint32 PCM byte count`, and
  raw PCM into the LoLa fragment/message layer.
- The raw frame builder is shared: audio send and video send paths call
  `FUN_140020ba0` to build Ethernet/IPv4/UDP frames before WinPcap transmit.
- Receive writes into fixed 100-slot remote playback rings; the PortAudio
  callback consumes rings and falls back to silence/dropout on missing data.
- Local and remote WAV recording drain side rings in separate threads.
- `LolaGui.ini` defaults include `socketport=7000`, `audioport=19788`,
  `videoport=19798`, `AudioTxFixedBuffer=1`, `WinPcap_SetMinToCopy=10`, and
  `RxPacketFiltering=1`; the same keys appear in the save path.

Strong inference:

- The real latency contract is "driver callback -> immediate packetization ->
  fixed receive ring", not conferencing-style adaptive jitter buffering.
- `AudioTxFixedBuffer` pads smaller channel-count payload capacity toward an
  8-channel class for packet-size stability.
- Generated audio signal is a control-message-driven test path that swaps the
  send-thread PCM source away from live capture.

Runtime gap:

- 48 kHz operation is unresolved. Strings and negotiation fields mention sample
  rate, but the recovered stream-open path uses `44100.0`.
- Byte-for-byte transport framing needs a live Windows packet capture.
- Clock drift and realignment behavior need a live peer because static analysis
  can identify counters and ring operations but cannot measure timing.

Mac-port implication:

- Implement the audio path first with a non-blocking Core Audio/HAL callback,
  fixed 64-frame blocks, explicit LoLa payload serialization, and visible
  dropout counters. Do not add video, recording, UI, or adaptive buffering to
  the audio realtime path.

## Video E2E Strategy

Static fact:

- XIMEA capture uses `xiGetImage(handle, 1000, ...)` on a capture thread.
- XIMEA setup directly programs `exposure`, `imgdataformat`, `width`,
  `height`, `offsetX`, `offsetY`, `cms`, `auto_wb`, and color parameters from
  `XimeaColors.ini`.
- Local preview is set up by `FUN_140012c00` and the preview helper
  `FUN_14000efc0`, which combines `xiGetImage`, OpenCV resize/drawing helpers,
  and the GDI/DIB display surface family.
- Local video uses a 30-slot frame ring and `VideoFrameReady%d` handoff.
- Raw video serializes a frame counter, payload length, and bytes before LoLa
  fragmentation.
- MJPEG uses IJG/libjpeg in the v2.0 main binary; the v1.5 CUDA executable is
  the proven GPUJPEG branch.
- Video send uses the shared LoLa fragmenter and raw Ethernet/IP/UDP packet
  builder before WinPcap send queues.
- Receive uses `pcap_next_ex`, fragment reassembly, raw copy or IJG/libjpeg
  decode, remote display handoff, counters, and recording side events.
- GDI/DIB display is proven through `CreateDIBSection`, `SetDIBColorTable`, and
  `StretchBlt`; DirectX/SIMD strings remain capability/residue evidence until
  runtime or branch proof shows an active DirectX path.

Strong inference:

- Video is low-latency and drop-oriented, but it tolerates blocking camera
  waits, JPEG work, display work, and visual degradation that audio cannot.
- The correct first E2E shape is raw video first, then MJPEG compatibility,
  with bounded rings, explicit frame-drop counters, and no video work on audio
  realtime threads.

Runtime gap:

- XIMEA buffer ownership, exact compression enum values, exact
  `OptimizeJpegDecompression` branch semantics, packet marker bytes, and PtGrey
  runtime reachability require hardware or live execution.
- The GDI/DIB display surface is proven statically; DirectX/SIMD strings remain
  display capability strings until runtime or deeper branch proof shows an
  active DirectX rendering path.

Mac-port implication:

- Keep video as a separate capture/encode/decode/display pipeline behind the
  proven audio transport. Use degraded modes deliberately: lower resolution,
  lower frame rate, grayscale, lower JPEG quality, and frame dropping under
  load.
