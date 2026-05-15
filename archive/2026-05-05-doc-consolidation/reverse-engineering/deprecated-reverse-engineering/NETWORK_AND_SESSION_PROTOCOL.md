# Reverse Engineering: Network And Session Protocol

Back to index: [README.md](../README.md)

Scope: docs-only static reverse-engineering refresh for LoLa origins, network
initialization, session/control workflow, local TX/RX processing, and the
end-to-end data path. No Windows executable was run. No Wine, activation work,
hardware probing, or live packet capture was used.

Primary target:

- `../win-compiled/2-0/LolaGui_XIMEA_x64.exe`

Comparison targets:

- `../win-compiled/1-5/LolaGui_XIMEA_x64.exe`
- `../win-compiled/1-5/LolaGui_XIMEA_CUDA_x64.exe`
- `../win-compiled/2-0/LolaGui_Tester/LolaGui_TESTER_x64.exe`

Evidence labels:

- Static fact: directly visible in imports, strings, PE metadata, hashes,
  disassembly, or Ghidra caller/decompiler output.
- Strong inference: multiple static facts point to one workflow, but live
  runtime state was not observed.
- Medium inference: the static evidence is real, but branch coverage or field
  semantics are not fully pinned down.
- Runtime gap: requires Windows execution, packet capture, hardware, a peer, or
  original symbols.

## Fresh Static Evidence

Static fact: the focused scratch script
`/private/tmp/lola-ghidra-scripts/LoLaNetworkSessionDeepDive.java` was run with
Ghidra 12.0.4 headless against the four targets above. Outputs stayed under
`/private/tmp/lola-ghidra-output`, and `-deleteProject` left
`/private/tmp/lola-ghidra-projects` empty.

Static fact: the v2.0 main GUI run strengthened the network/session map around:

- `FUN_140016f20`: WinPcap capture setup, open, BPF compile, BPF setfilter,
  `pcap_setmintocopy`, and receive-thread start.
- `FUN_14001fb60`: control-message builder.
- `FUN_14001f390`: control-message parser/dispatcher.
- `FUN_14002a6e0`: `LolaGui.ini` load path.
- `FUN_140031d70`: settings/session save path.
- `FUN_140009bf0`: audio TX path.
- `FUN_1400115c0` and `0x140011680`: raw video TX path.
- `FUN_140011c10`: MJPEG TX path.
- `FUN_1400152d0`: shared RX/reassembly/decode path.
- `FUN_140006e80`, `FUN_140006e90`, `FUN_140006f00`,
  `FUN_1400070b0`, `FUN_140007200`: receive/fragment helpers.
- `FUN_140020ba0`: shared raw Ethernet/IPv4/UDP frame builder.
- `FUN_140020d70`: single-packet WinPcap open/send/close helper.

Runtime gap: because Windows system DLL bodies and PDBs were unavailable on
this Mac, imported API names and caller clusters are strong enough to map
surfaces, but not enough to prove every source-level function name.

Corpus cross-link: the later full-corpus origins pass keeps this file as the
network/session detail artifact. See
[CORPUS_ORIGINS_AND_INTEGRATION.md](CORPUS_ORIGINS_AND_INTEGRATION.md) for the
package-wide role split between the v2.0 main GUI, older tester, offline
helpers, third-party runtimes, installers, and camera/config payloads.

## Origins And Lineage Snapshot

Static fact: embedded strings identify the product as LoLa, the Low Latency A/V
Streaming application. The artifacts contain `LOLA Team:`, `lola.conts.it`,
`TartiniLola`, LoLa utility names, Independent JPEG Group notices, and
GPUJPEG/CESNET notices.

Static fact: version and build markers include:

| Artifact | Version/origin evidence |
|---|---|
| v1.5 main GUI | `1.5.0`, `150.012`, VC++ 2010/MFC100 lineage, LoLa team strings. |
| v1.5 CUDA GUI | v1.5 main lineage plus `gpujpeg.dll`, `M-JPEG (GPU)`, and GPUJPEG encode/decode caller clusters. |
| v2.0 main GUI | `2.0.0 - Beta 1`, MSVC 14.22/MFC140 lineage, build path `F:\000_LOLA OFFICIAL RELEASE\GuiProjects2\GUIProjects\NewLolaGUI\intermediate\x64\Release\LolaGui.pdb`. |
| Tester | `Lola Tester 1.0.3 (based on Lola ver. 1.3.0)`. |
| Utilities | `Lola Video Converter - Version 1.0.21` and `Lola Wav Splitter - Version 1.0.14`. |

Static fact: package comparison shows 21 byte-identical common files between
v1.5 and v2.0, with only `LolaGui_XIMEA_x64.exe` and `CAMERAFILES/Ximea.ini`
changed among common relative paths. v2.0 adds VC++ 2015-2019 runtime DLLs and
root `XimeaColors.ini`; v1.5 alone contains the CUDA GUI and many legacy
Imperx/BitFlow/analog camera payloads.

Strong inference: v2.0 is an assembled runtime distribution around a newer main
GUI and XIMEA configuration, not a from-scratch rewrite of every bundled tool.
The byte-identical tester and utilities are support artifacts, while
`../win-compiled/2-0/LolaGui_XIMEA_x64.exe` is the active v2.0 live
XIMEA/network target.

## Network Initialization

Static fact: the v2.0 main GUI imports WinPcap from `wpcap.dll`:

- `pcap_findalldevs_ex`
- `pcap_findalldevs`
- `pcap_open`
- `pcap_close`
- `pcap_compile`
- `pcap_setfilter`
- `pcap_setmintocopy`
- `pcap_next_ex`
- `pcap_sendpacket`
- `pcap_sendqueue_alloc`
- `pcap_sendqueue_queue`
- `pcap_sendqueue_transmit`
- `pcap_sendqueue_destroy`
- `pcap_freealldevs`

Static fact: the v2.0 main GUI imports adapter/reachability APIs from
`IPHLPAPI.DLL`: `GetAdaptersInfo`, `SendARP`, `IcmpCreateFile`,
`IcmpSendEcho`, and `IcmpCloseHandle`.

Static fact: the v2.0 main GUI imports Winsock from `WS2_32.dll`; named imports
include `inet_pton`, `getnameinfo`, `freeaddrinfo`, and `getaddrinfo`, with
additional ordinal imports. The binary also embeds `WSAStartup failed with
error: %d`, `Winsock error: Unable to start listening socket`, and `Winsock
error: Bind failed`.

Static fact: `FUN_140016f20` is the v2.0 WinPcap capture-open path. Its Ghidra
output shows:

- `pcap_findalldevs`
- `pcap_open(..., 0x10000, 8, 500)`
- `pcap_setmintocopy`
- `pcap_compile`
- `pcap_setfilter`
- `pcap_freealldevs`
- BPF strings `ip and udp` and
  `ip and src host %s and dst host %s and (udp port %d or udp port %d)`

Static fact: the focused caller surface also finds:

| API | v2.0 caller evidence |
|---|---|
| `pcap_findalldevs` | `FUN_14000a000`, `FUN_140012490`, `FUN_140016f20`, `FUN_140028af0`. |
| `pcap_findalldevs_ex` | `FUN_140020920`. |
| `pcap_open` | `FUN_14000a000`, `FUN_140012490`, `FUN_140016f20`, `FUN_140020d70`. |
| `pcap_compile` / `pcap_setfilter` | `FUN_140016f20`. |
| `pcap_setmintocopy` | `FUN_140016f20`. |
| `GetAdaptersInfo` | `FUN_140020660`. |
| `SendARP` | `FUN_1400205b0`, `FUN_140020660`. |
| `IcmpCreateFile` / `IcmpSendEcho` / `IcmpCloseHandle` | `FUN_14002b650`. |

Static fact: `LolaGui.ini` network keys are loaded by `FUN_14002a6e0` and saved
by `FUN_140031d70`. The loader defaults recovered by Ghidra are:

| Key | Default | Meaning |
|---|---:|---|
| `socketport` | `7000` | Control/listening socket setting. |
| `audioport` | `19788` (`0x4d4c`) | Audio media UDP/WinPcap path. |
| `videoport` | `19798` (`0x4d56`) | Video media UDP/WinPcap path. |
| `WinPcap_SetMinToCopy` | `10` | Capture batching/min-copy tuning surface. |
| `RxPacketFiltering` | `1` | Advanced host/port filter toggle. |
| `AudioTxFixedBuffer` | `1` | Fixed-size audio payload compatibility surface. |

Strong inference: the initialization flow is:

```text
load INI/session settings
  -> enumerate NICs and WinPcap devices
  -> resolve/validate local and remote addresses
  -> optional ICMP/ARP reachability checks
  -> open the selected WinPcap adapter
  -> apply min-copy and optional BPF filtering
  -> start media RX/TX threads
```

Runtime gap: exact adapter selection UI state, the final generated BPF string
for each user setting, and behavior when multiple NICs match still need a live
Windows run.

## Control And Session Workflow

Static fact: v2.0 embeds these control-message builder formats in
`FUN_14001fb60`:

```text
/MESG_CHECKLOLASTATUS;SRCIP:%s;DSTIP:%s;SID:%d;
/MESG_CHECKLOLASTATUS_ACK;SRCIP:%s;DSTIP:%s;SID:%d;
/MESG_QUICKCONN;SRCIP:%s;DSTIP:%s;SID:%d;SR:%d;BPS:%d;CHNLS:%d;FPS:%d;BPP:%d;X:%d;Y:%d;COMP:%d;BAYER:%d
/MESG_QUICKCONN_ACK;SRCIP:%s;DSTIP:%s;SID:%d;SR:%d;BPS:%d;CHNLS:%d;FPS:%d;BPP:%d;X:%d;Y:%d;COMP:%d;BAYER:%d
/MESG_REJECT;SRCIP:%s;DSTIP:%s;SID:%d;TXT:%s
/MESG_DISCONNECT;SRCIP:%s;DSTIP:%s;SID:%d;
/MESG_SWITCH_ON_BB;SRCIP:%s;DSTIP:%s;SID:%d;
/MESG_SWITCH_OFF_BB;SRCIP:%s;DSTIP:%s;SID:%d;
/MESG_CHAT;SRCIP:%s;DSTIP:%s;SID:%d;TXT:%s
/MESG_SEND_AUDIO_SIGNAL;SRCIP:%s;DSTIP:%s;SID:%d
/MESG_STOP_AUDIO_SIGNAL;SRCIP:%s;DSTIP:%s;SID:%d
```

Static fact: `FUN_14001f390` parses matching names, tokenizes `SRCIP:` and
`DSTIP:`, dispatches quick connect, ACK, disconnect, reject, bounce-back,
generated-audio-signal, and chat cases, and posts window/control messages.

Static fact: quick-connect fields cover both audio and video parameters:

- `SRCIP`
- `DSTIP`
- `SID`
- `SR`
- `BPS`
- `CHNLS`
- `FPS`
- `BPP`
- `X`
- `Y`
- `COMP`
- `BAYER`
- `TXT` for reject/chat text

Static fact: the user-facing control surface includes:

- `Connection already established on Session %d.`
- `Connection to localhost not allowed. Type a valid remote host address.`
- `Session %d connection info`
- `No reply from remote host (%s) within 3 sec! Try again.`
- `Session %d: Lola on remote host (%s) refused to connect.`
- `[Remote %s has disconnected successfully]`
- `LolaChatDlg`
- `Disable Chat`
- `lola.ForceDisconnect(`
- `lola.GetRemoteInfo()`
- `lola.GetRemoteSettings()`

Strong inference: the v2.0 session workflow is:

```text
settings/NIC/remote host selected
  -> ICMP/ARP/address checks
  -> /MESG_CHECKLOLASTATUS
  -> /MESG_CHECKLOLASTATUS_ACK
  -> /MESG_QUICKCONN with audio/video media parameters
  -> /MESG_QUICKCONN_ACK or /MESG_REJECT
  -> active session with WinPcap media paths
  -> optional chat, bounce-back, generated audio signal, monitor queries
  -> /MESG_DISCONNECT
```

Strong inference: v2.0 moved from the v1.5 OSC-looking control lineage toward
explicit semicolon/key-value control messages because v2.0 has `SRCIP`, `DSTIP`,
and `SID:%d` builder/parser clusters, while v1.5 and the tester retain
OSC/parser strings and older `/MESG_ACCEPT`, `/MESG_BOUNCEBACKCONN`, and
`/MESG_BAYER_DECODING` names.

Runtime gap: static analysis proves the application-message formats but not the
complete control transport framing. The exact delimiter, escaping behavior for
`TXT:%s`, timeout/retry details, socket-vs-packet route per message, and byte
ordering of any surrounding transport fields require live tracing.

## Local Processing And TX

Static fact: `FUN_140009bf0` is the v2.0 audio TX cluster. It waits on capture
events, calls the shared fragmenter and raw packet builder, and sends through
`pcap_sendpacket`. Its Ghidra output shows `pcap_sendpacket`, wrapper size
`0x2a`, and message/fragment header arithmetic around `0x21`.

Strong inference: the audio TX path serializes a sequence number, PCM byte
count, and raw signed-16-bit PCM block before LoLa fragmentation. This is based
on the address-level audio reconstruction plus the focused Ghidra caller map.

Static fact: `FUN_1400115c0` and inner address `0x140011680` share the raw
video TX function body. The function uses `pcap_sendqueue_alloc`,
`pcap_sendqueue_queue`, `pcap_sendqueue_transmit`, and
`pcap_sendqueue_destroy`.

Static fact: `FUN_140011c10` is the MJPEG TX cluster. It adds IJG/libjpeg
compression (`jpeg_CreateCompress`, `jpeg_mem_dest`, `jpeg_set_quality`,
`jpeg_write_scanlines`) before the same LoLa fragmenter/raw-packet/sendqueue
path.

Static fact: `FUN_1400070b0` is called by audio send, raw video send, and MJPEG
send. Its Ghidra decompiler output shows `0x21` payload offset arithmetic and
the `0xeeeeeeee` marker write.

Static fact: `FUN_140020ba0` is the shared raw Ethernet/IPv4/UDP builder for
audio and video sends. It is called from `FUN_140009bf0`, `FUN_1400115c0`, and
`FUN_140011c10`; its decompiler output shows payload offset `0x2a` and IPv4
identifier constant `0x1337`.

Static fact: `FUN_140020d70` is a single-packet helper that opens a WinPcap
device, calls `pcap_sendpacket`, and closes it. The focused run found no normal
incoming callers for this helper in the recovered v2.0 main-GUI graph.

Runtime gap: exact fragment header layout, marker semantics, and whether
`FUN_140020d70` is debug/dead/indirectly called require deeper data-flow or
runtime proof.

## RX And End-To-End Behavior

Static fact: `FUN_1400152d0` is the shared media RX cluster. Its Ghidra output
shows:

- `pcap_next_ex`
- `pcap_sendqueue_alloc(100000)` and cleanup
- helper calls to `FUN_140006e80`, `FUN_140006e90`, `FUN_140006f00`,
  `FUN_140007200`, and adjacent reassembly helpers
- IJG/libjpeg decompression calls
- event/counter/display/recording handoffs

Static fact: RX helper evidence includes:

| Helper | Static role evidence |
|---|---|
| `FUN_140006e80` | Called from `FUN_1400152d0`; decompiler sees counter comparison around offset `0x40`. |
| `FUN_140006e90` | Called from `FUN_1400152d0`; tiny helper in the reassembly cluster. |
| `FUN_140006f00` | Called from `FUN_1400152d0`; allocation/reset helper with `0x40` signal. |
| `FUN_1400070b0` | Shared TX fragment/message helper with `0x21` header arithmetic. |
| `FUN_140007200` | Called from `FUN_1400152d0`; copies payload from offset `0x21` and advances counter state. |

Strong inference: RX path behavior is:

```text
pcap_next_ex packet loop
  -> host/port/session filtering
  -> LoLa fragment reassembly
  -> audio payload insertion into fixed remote playback ring
  -> raw video copy or MJPEG decode
  -> display and recording events
  -> drop/incomplete/orphan/realign counters
```

Static fact: monitor strings expose the counters the runtime considers
important:

- `Audio RX frames`
- `Audio Incomplete packets`
- `Audio Dropped packets`
- `Audio Realigned buffers`
- `Video RX frames`
- `Video Dropped frames`
- `Video Dropped start_frames`
- `Video Orphans sub_frames`
- `Video Dropped sub_frames`
- `Video Remote FpS settings`
- `Video Remote Window FpS`
- `Video Received FpS`
- `Video Sent FpS`

Strong inference: the transport is designed to drop, realign, and continue
rather than block for recovery. This matches the audio callback/ring evidence
and the video frame/drop-counter evidence.

Runtime gap: only a live peer and packet capture can prove exact packet grammar,
fragment loss behavior, clock drift behavior, and the final order of display
and recording side effects.

## Lineage Comparison

| Surface | v1.5 main/CUDA | v2.0 main | Tester |
|---|---|---|---|
| Control vocabulary | Static fact: `/MESG_CHECKLOLASTATUS`, `/MESG_QUICKCONN`, `/MESG_QUICKCONN_ACK`, `/MESG_ACCEPT`, `/MESG_BOUNCEBACKCONN`, `/MESG_BAYER_DECODING`, `/MESG_CHAT`; OSC parser/socket class strings. | Static fact: semicolon/key-value `/MESG_*` builder/parser strings with `SRCIP`, `DSTIP`, `SID`, media fields, `TXT`, reject, disconnect, bounce-back toggles, chat, and generated audio signal. | Static fact: older tester vocabulary including `/MESG_ACCEPT` and `/MESG_BOUNCEBACKCONN`; based on LoLa 1.3.0. |
| WinPcap media path | Static fact: same broad `pcap_next_ex`, sendqueue, BPF, min-copy, audio/video ports. | Static fact: same broad path plus `pcap_findalldevs_ex` import/caller surface. | Static fact: WinPcap and monitor/config vocabulary present, but no XIMEA import surface. |
| GPUJPEG boundary | Static fact: v1.5 CUDA imports `gpujpeg.dll` and has GPUJPEG encode/decode caller clusters. | Static fact: no `gpujpeg.dll` import/caller cluster in the v2.0 main GUI. | Static fact: tester is CPU/test-emulation oriented and does not prove v2.0 XIMEA GPU path. |
| Runtime artifacts | Static fact: tester, converter, WAV splitter, PortAudio, OpenCV, JPEG DLLs, GPUJPEG DLL, XIMEA installer, WinPcap installer are unchanged between matching v1.5/v2.0 paths unless separately noted. | Static fact: v2.0 main GUI and `CAMERAFILES/Ximea.ini` changed; v2.0 adds VC++ 2015-2019 DLLs and `XimeaColors.ini`. | Static fact: tester is byte-identical between v1.5 and v2.0 package paths. |

## Confidence

High confidence:

- Static fact: WinPcap is central to audio/video packet TX/RX.
- Static fact: v2.0 embeds plaintext control/chat builder and parser strings
  with `SRCIP`, `DSTIP`, and `SID`.
- Static fact: quick connect carries audio/video media parameters.
- Static fact: `socketport=7000`, `audioport=19788`, `videoport=19798`,
  `WinPcap_SetMinToCopy=10`, and `RxPacketFiltering=1` are loader defaults.
- Static fact: `FUN_140016f20` opens WinPcap, configures min-copy, and applies
  BPF filtering.
- Static fact: audio TX uses `pcap_sendpacket`; video TX uses WinPcap
  sendqueues; RX uses `pcap_next_ex`.
- Static fact: v1.5 CUDA is the proven GPUJPEG branch; v2.0 main is not.

Medium confidence:

- Strong inference: `socketport` is the control/listening port and
  `audioport`/`videoport` are media data-path ports.
- Strong inference: v2.0 replaced or wrapped the v1.5 OSC-looking control
  layer with explicit semicolon/key-value session messages.
- Strong inference: generated audio signal is a real test-source path driven by
  control messages and the audio TX loop.
- Medium inference: the RX helper cluster names above map cleanly to fragment
  lifecycle stages, but exact field names remain unknown.

Runtime gaps:

- Exact control-message transport and byte framing.
- Text escaping and maximum lengths for `TXT:%s`.
- Exact audio/video fragment grammar and marker semantics.
- Actual runtime overrides from user-generated INI/session files.
- Behavior under loss, multiple NICs, clock drift, multiple sessions, and real
  LoLa peers.
