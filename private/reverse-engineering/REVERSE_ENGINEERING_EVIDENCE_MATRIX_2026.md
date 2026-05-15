# Open Lola Reverse Engineering Evidence Matrix 2026

Back to private index:
[README.md](README.md)

Date: 2026-05-02  
Status: internal static-evidence ledger, current after public boundary restructure
Canonical private evidence set:
[README.md](README.md)

Scope: canonical static evidence register for the Windows LoLa corpus in
Verdict: PARTIAL
`../../archive/2026-05-11-win-compiled/win-compiled/1-5` and `../../archive/2026-05-11-win-compiled/win-compiled/2-0`.

## Evidence Level Legend

- Static fact: directly visible in inventory, hashes, PE metadata, imports,
  exports, version resources, strings, resources, disassembly, or Ghidra output.
- Strong inference: multiple static facts point to one behavior or role, but no
  live runtime was observed.
- Medium inference: static evidence is real, but semantic branch coverage is
  not fully pinned down.
- Runtime gap: requires Windows execution, hardware, packet capture, a peer,
  original symbols, or source code.

## Matrix

| ID | Claim | Level | Evidence | Confidence | Remaining gap |
|---:|---|---|---|---|---|
| 1 | The corpus is LoLa low-latency A/V streaming software. | Static fact | Product strings, LoLa team strings, `lola.conts.it`, `TartiniLola`, utility names. | High | None for identity. |
| 2 | Full non-`.DS_Store` corpus contains 100 files. | Static fact | Scratch Python/LIEF inventory over `win-compiled`. | High | None for static file count. |
| 3 | v1.5 has 72 files and v2.0 has 28 files. | Static fact | Corpus inventory and package counts. | High | None for static file count. |
| 4 | Static role classification is 3 LoLa apps, 6 LoLa helpers, 34 runtimes, 4 installers, 53 config/camera payloads. | Static fact | Corpus inventory classification. | High | Semantic labels are static-role labels, not runtime behavior. |
| 5 | v2.0 main GUI is the active analyzed current live target. | Static fact | `2.0.0 - Beta 1`, MSVC 14.22/MFC140, XIMEA/PortAudio/WinPcap/JPEG/GDI caller clusters. | High | Other unshipped builds are unknown. |
| 6 | v2.0 is an assembled runtime distribution. | Strong inference | 2019 main GUI, 2020 XIMEA DLL timestamp, unchanged 2014 helpers, unchanged runtimes/installers, v2.0-only VC runtime files. | High | Original packaging process. |
| 7 | Tester is older support/emulation lineage. | Static fact | Byte-identical v1.5/v2.0 tester; `Lola Tester 1.0.3 (based on Lola ver. 1.3.0)`. | High | Runtime tester behavior. |
| 8 | Video converter is an offline helper, not live transport. | Static fact | Byte-identical helper, OpenCV/IJG conversion strings, no XIMEA/WinPcap/PortAudio live import surface. | High | Exact recorded-file variants. |
| 9 | WAV splitter is an offline helper, not live transport. | Static fact | Byte-identical helper, WAV splitting/conversion strings, no live transport surface. | High | Exact file variants. |
| 10 | v1.5 CUDA GUI proves a GPUJPEG branch. | Static fact | `gpujpeg.dll` imports and GPU JPEG encode/decode caller evidence in `LolaGui_XIMEA_CUDA_x64.exe`. | High | Runtime performance. |
| 11 | v2.0 main has no statically proven active GPUJPEG call path. | Static fact | GPUJPEG strings/settings exist, but no `gpujpeg.dll` import/caller cluster in v2.0 main. | High | Dynamic-load proof if present. |
| 12 | v2.0 package is XIMEA/PtGrey-centered for shipped camera files. | Strong inference | Expanded `Ximea.ini`, retained `PtGrey.ini`, v2.0-only `XimeaColors.ini`, removed legacy `.kcxp`/`.anlg` payloads. | High | Runtime reachability for PtGrey. |
| 13 | PtGrey runtime support is not proven in the analyzed v2.0 XIMEA GUI. | Runtime gap | `PtGrey.ini` exists but no PtGrey/FlyCapture import surface was visible. | High for gap | Dynamic-load/source/runtime proof. |
| 14 | v2.0 captures XIMEA video. | Static fact | XIMEA imports and callers for `xiOpenDevice`, `xiSetParam*`, `xiStartAcquisition`, `xiGetImage`. | High | Hardware timing. |
| 15 | v2.0 uses PortAudio/ASIO for audio. | Static fact | PortAudio imports and callers for ASIO enumeration, buffer-size probing, and `Pa_OpenStream`. | High | Hardware timing. |
| 16 | The recovered audio open path uses 64-frame int16 behavior and `44100.0`. | Strong inference | Disassembly/Ghidra open-path constants and PortAudio sample format evidence. | High | Runtime overrides and 48 kHz interop. |
| 17 | 48 kHz operation is not proven. | Runtime gap | Sample-rate strings exist, but recovered open/WAV path stays on 44.1 kHz. | High for gap | Live peer/hardware test. |
| 18 | Audio callback local work is bounded copy/gain/ring/event work. | Static fact | Callback disassembly shows int16 gain scaling, capture buffers, remote ring copy/clear, recording copies. | Medium | Exact overflow/clamp behavior. |
| 19 | Audio TX uses WinPcap media send. | Static fact | Audio send function calls `pcap_sendpacket` and shared raw packet builder. | High | Live packet bytes. |
| 20 | Raw video TX uses WinPcap send queues. | Static fact | `FUN_1400115c0` and related callers use `pcap_sendqueue_*`. | High | Live packet bytes. |
| 21 | MJPEG TX uses IJG/libjpeg plus WinPcap send queues. | Static fact | `FUN_140011c10` and JPEG caller/import evidence. | High | Runtime quality/timing. |
| 22 | RX uses `pcap_next_ex` and fragment reassembly. | Static fact | Receive-loop caller evidence, reassembly helpers, audio ring insertion, video raw copy/JPEG decode paths. | High | Packet loss behavior. |
| 23 | Shared raw Ethernet/IPv4/UDP builder exists. | Static fact | Shared packet-builder function and call sites from audio/video paths. | High | Full payload grammar. |
| 24 | Network setup opens WinPcap devices and applies BPF filtering. | Static fact | `pcap_findalldevs*`, `pcap_open`, `pcap_compile`, `pcap_setfilter`, `pcap_setmintocopy`; filter strings. | High | Runtime selected NIC behavior. |
| 25 | Adapter/reachability support exists. | Static fact | `GetAdaptersInfo`, `SendARP`, ICMP, `getaddrinfo`, `getnameinfo`, `inet_pton` imports/callers. | High | Network environment. |
| 26 | Control/chat message layer is plaintext at embedded format-string level. | Static fact | `/MESG_*`, `SRCIP`, `DSTIP`, `SID`, `TXT` strings. | High | Exact transport/framing. |
| 27 | Quick connect, ACK/reject, disconnect, chat, bounce-back, and generated-audio-signal paths are present. | Static fact | Builder/parser functions `FUN_14001fb60` and `FUN_14001f390`. | High | Exact UI state transitions. |
| 28 | Default ports are control 7000, audio 19788, video 19798. | Static fact | `LolaGui.ini` loader evidence for `socketport`, `audioport`, `videoport`. | High | Runtime overrides in user INI. |
| 29 | Registry and hardware metadata participate in activation or host identity. | Medium inference | Serial dialog, Registry imports, CPU/BIOS/mainboard strings. | Medium | Exact validation algorithm. |
| 30 | No TLS/certificate/authenticated key-exchange surface was found. | Static fact | Static string/import surface lacks TLS/certificate indicators. | Medium | Runtime/dynamic libraries not observed. |
| 31 | Helper tools are not live media transport participants. | Static fact | Converter/splitter have no live network/camera/audio driver surfaces; tester is separate support lineage. | High | Runtime use by operators. |
| 32 | The Mac-native implementation should use LoLa as evidence, not a compatibility contract. | Strong inference | `archive/2026-05-05-workflow-consolidation/superseded/root/MAC_PORT_PLAN.md` states Windows compatibility is no longer required; reverse engineering shows useful design traps. | High | Product decision changes. |

## Source Files

Canonical summaries:

- [REVERSE_ENGINEERING_ARTIFACTS_AND_ORIGINS_2026.md](REVERSE_ENGINEERING_ARTIFACTS_AND_ORIGINS_2026.md)
- [REVERSE_ENGINEERING_LOLA_E2E_WORKFLOW_2026.md](REVERSE_ENGINEERING_LOLA_E2E_WORKFLOW_2026.md)
- [REVERSE_ENGINEERING_SECURITY_COMMANDS_CONFIDENCE_2026.md](REVERSE_ENGINEERING_SECURITY_COMMANDS_CONFIDENCE_2026.md)

Historical detail:

- [deprecated-reverse-engineering/ARTIFACTS_AND_VERSIONING.md](../../archive/2026-05-05-doc-consolidation/reverse-engineering/deprecated-reverse-engineering/ARTIFACTS_AND_VERSIONING.md)
- [deprecated-reverse-engineering/AUDIO_WORKFLOW_REVERSE_ENGINEERING.md](../../archive/2026-05-05-doc-consolidation/reverse-engineering/deprecated-reverse-engineering/AUDIO_WORKFLOW_REVERSE_ENGINEERING.md)
- [deprecated-reverse-engineering/VIDEO_WORKFLOW_REVERSE_ENGINEERING.md](../../archive/2026-05-05-doc-consolidation/reverse-engineering/deprecated-reverse-engineering/VIDEO_WORKFLOW_REVERSE_ENGINEERING.md)
- [deprecated-reverse-engineering/NETWORK_AND_SESSION_PROTOCOL.md](../../archive/2026-05-05-doc-consolidation/reverse-engineering/deprecated-reverse-engineering/NETWORK_AND_SESSION_PROTOCOL.md)
- [deprecated-reverse-engineering/SECURITY_COMMANDS_CONFIDENCE.md](../../archive/2026-05-05-doc-consolidation/reverse-engineering/deprecated-reverse-engineering/SECURITY_COMMANDS_CONFIDENCE.md)
